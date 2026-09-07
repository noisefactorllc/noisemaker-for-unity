using System;
using System.Collections.Generic;
using System.Diagnostics;
using Noisemaker.Hlsl.Compiler.Graph;

namespace Noisemaker.Hlsl
{
    public sealed class MidiNote
    {
        public int Key { get; internal set; }
        public int Velocity { get; internal set; }
        public double TimeMilliseconds { get; internal set; }
        public long Order { get; internal set; }
        public MidiChannelState Channel { get; internal set; }
        public int ChannelNumber { get; internal set; }
        internal object Origin;
    }

    public sealed class MidiParameterChange
    {
        public string Family { get; internal set; }
        public int Parameter { get; internal set; }
        public int Value { get; internal set; }
        internal List<int> ResetChannels;
    }

    public sealed class MidiPortInfo
    {
        public string Id { get; set; }
        public string Name { get; set; }
        public bool Connected { get; set; } = true;
    }

    public sealed class MidiChannelState
    {
        private static long _noteOrder;
        internal static readonly HashSet<int> RetainedControllers = new HashSet<int>
            { 0, 32, 7, 10, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 91, 92, 93, 94, 95 };
        public int Key { get; set; }
        public int Velocity { get; set; }
        public int Gate { get; set; }
        public double TimeMilliseconds { get; set; }
        public byte[] Keys { get; } = new byte[128];
        public byte[] Cc { get; } = new byte[128];
        public ushort[] Cc14 { get; } = new ushort[32];
        public int PitchBend { get; set; } = 8192;
        public int Pressure { get; set; }
        public byte[] PolyPressure { get; } = new byte[128];
        public Dictionary<int, int> Nrpn { get; } = new Dictionary<int, int>();
        public Dictionary<int, int> Rpn { get; } = new Dictionary<int, int>();
        public Dictionary<int, MidiNote> HeldNotes { get; } = new Dictionary<int, MidiNote>();
        internal int?[] NrpnSelector = new int?[2];
        internal int?[] RpnSelector = new int?[2];
        internal string ParameterFamily;
        internal readonly object[] CcOrigins = new object[128];
        internal readonly object[] Cc14Origins = new object[32];
        internal readonly object[] PolyPressureOrigins = new object[128];
        internal readonly Dictionary<int, object> NrpnOrigins = new Dictionary<int, object>();
        internal readonly Dictionary<int, object> RpnOrigins = new Dictionary<int, object>();
        internal object PitchBendOrigin;
        internal object PressureOrigin;

        public void NoteOn(int key, int velocity, double? timestampMilliseconds = null)
        {
            ApplyNoteOn(key, velocity, timestampMilliseconds, null, null);
        }

        internal void ApplyNoteOn(int key, int velocity, double? timestampMilliseconds,
            MidiNote sourceNote, object origin)
        {
            if (key < 0 || key > 127 || velocity < 0 || velocity > 127) return;
            Key = key; Velocity = velocity; Gate = 1;
            TimeMilliseconds = sourceNote?.TimeMilliseconds ?? timestampMilliseconds ?? CurrentMilliseconds();
            Keys[key] = (byte)velocity;
            HeldNotes[key] = new MidiNote { Key = key, Velocity = velocity,
                TimeMilliseconds = TimeMilliseconds, Origin = origin,
                Order = sourceNote?.Order ?? System.Threading.Interlocked.Increment(ref _noteOrder) };
        }

        public void NoteOff() { ClearNotes(); }
        public void NoteOff(int key)
        {
            Gate = 0;
            if (key < 0 || key > 127) return;
            Keys[key] = 0; HeldNotes.Remove(key); PolyPressure[key] = 0;
        }

        public MidiParameterChange ControlChange(int controller, int value)
        {
            if (controller < 0 || controller > 127 || value < 0 || value > 127) return null;
            Cc[controller] = (byte)value;
            if (controller < 64)
            {
                int msb = controller & 31;
                Cc14[msb] = (ushort)((Cc[msb] << 7) | Cc[msb + 32]);
            }
            if (controller == 121) ResetControllers();
            else if (controller == 120 || controller == 123) ClearNotes();
            else if (controller == 99 || controller == 98 || controller == 101 || controller == 100)
            {
                ParameterFamily = controller < 100 ? "nrpn" : "rpn";
                int?[] selector = ParameterFamily == "nrpn" ? NrpnSelector : RpnSelector;
                selector[controller == 99 || controller == 101 ? 0 : 1] = value;
            }
            else if ((controller == 6 || controller == 38 || controller == 96 || controller == 97) && ParameterFamily != null)
            {
                int?[] selector = ParameterFamily == "nrpn" ? NrpnSelector : RpnSelector;
                if (!selector[0].HasValue || !selector[1].HasValue || (selector[0] == 127 && selector[1] == 127)) return null;
                int parameter = (selector[0].Value << 7) | selector[1].Value;
                Dictionary<int, int> values = ParameterFamily == "nrpn" ? Nrpn : Rpn;
                values.TryGetValue(parameter, out int previous);
                int next = controller == 6 ? value << 7 : controller == 38 ? (previous & 0x3f80) | value
                    : Math.Max(0, Math.Min(16383, previous + (controller == 96 ? 1 : -1)));
                values[parameter] = next;
                return new MidiParameterChange { Family = ParameterFamily, Parameter = parameter, Value = next };
            }
            return null;
        }

        public void ResetControllers()
        {
            for (int cc = 0; cc < 128; cc++)
                if (!RetainedControllers.Contains(cc)) Cc[cc] = (byte)(cc == 11 || (cc >= 98 && cc <= 101) ? 127 : 0);
            for (int cc = 0; cc < 32; cc++) Cc14[cc] = (ushort)((Cc[cc] << 7) | Cc[cc + 32]);
            PitchBend = 8192; Pressure = 0;
            Array.Clear(PolyPressure, 0, 128);
            ParameterFamily = null; NrpnSelector = new int?[2]; RpnSelector = new int?[2];
        }

        public void ClearNotes()
        {
            Gate = 0; Array.Clear(Keys, 0, 128); HeldNotes.Clear(); Array.Clear(PolyPressure, 0, 128);
        }

        public void Reset()
        {
            Key = Velocity = Gate = 0; TimeMilliseconds = 0;
            ClearNotes(); Array.Clear(Cc, 0, 128); Array.Clear(Cc14, 0, 32);
            Array.Clear(CcOrigins, 0, 128); Array.Clear(Cc14Origins, 0, 32);
            Array.Clear(PolyPressureOrigins, 0, 128);
            PitchBend = 8192; Pressure = 0; PitchBendOrigin = PressureOrigin = null;
            Nrpn.Clear(); Rpn.Clear(); NrpnOrigins.Clear(); RpnOrigins.Clear();
            ParameterFamily = null; NrpnSelector = new int?[2]; RpnSelector = new int?[2];
        }

        private static double CurrentMilliseconds()
        {
            return (double)Stopwatch.GetTimestamp() * 1000.0 / Stopwatch.Frequency;
        }
    }

    public sealed class MidiState
    {
        private sealed class Port
        {
            public string Name;
            public bool Connected;
            public MidiState State;
        }
        private static readonly object UnscopedOrigin = new object();
        private readonly MidiChannelState[] _channels = new MidiChannelState[17];
        private readonly Dictionary<string, Port> _ports;
        private readonly Dictionary<string, MidiState> _portsByName;
        private Dictionary<string, string> _portInventory;
        private readonly MidiState _unscopedState;
        public int? LowerZoneMembers { get; private set; }
        public int? UpperZoneMembers { get; private set; }
        public long ClockCount { get; private set; }

        public MidiState() : this(true) { }
        private MidiState(bool portRegistry)
        {
            for (int i = 1; i <= 16; i++) _channels[i] = new MidiChannelState();
            if (portRegistry)
            {
                _ports = new Dictionary<string, Port>();
                _portsByName = new Dictionary<string, MidiState>();
                _unscopedState = new MidiState(false);
            }
        }

        public MidiChannelState GetChannel(int channel)
        {
            return channel >= 1 && channel <= 16 ? _channels[channel] : _channels[1];
        }

        public MidiState RegisterPort(string id, string name)
        {
            if (_ports == null || string.IsNullOrEmpty(id)) return null;
            if (!_ports.TryGetValue(id, out Port port))
            {
                port = new Port { State = new MidiState(false) };
                _ports.Add(id, port);
            }
            port.Name = name ?? ""; port.Connected = true;
            RebuildPortNameIndex();
            return port.State;
        }

        public void DisconnectPort(string id)
        {
            if (_ports == null || string.IsNullOrEmpty(id) || !_ports.TryGetValue(id, out Port port)) return;
            port.Connected = false; port.State.Reset();
            for (int n = 1; n <= 16; n++)
            {
                var channel = _channels[n];
                for (int cc = 0; cc < 128; cc++)
                    if (Equals(channel.CcOrigins[cc], id)) { channel.Cc[cc] = 0; channel.CcOrigins[cc] = null; }
                for (int cc = 0; cc < 32; cc++)
                    if (Equals(channel.Cc14Origins[cc], id)) { channel.Cc14[cc] = 0; channel.Cc14Origins[cc] = null; }
                ClearNoteOrigin(channel, id);
                foreach (string family in new[] { "nrpn", "rpn" })
                {
                    var values = family == "nrpn" ? channel.Nrpn : channel.Rpn;
                    var origins = family == "nrpn" ? channel.NrpnOrigins : channel.RpnOrigins;
                    foreach (int parameter in new List<int>(origins.Keys))
                        if (Equals(origins[parameter], id)) { values.Remove(parameter); origins.Remove(parameter); }
                }
                if (Equals(channel.PitchBendOrigin, id)) { channel.PitchBend = 8192; channel.PitchBendOrigin = null; }
                if (Equals(channel.PressureOrigin, id)) { channel.Pressure = 0; channel.PressureOrigin = null; }
                for (int key = 0; key < 128; key++)
                    if (Equals(channel.PolyPressureOrigins[key], id)) { channel.PolyPressure[key] = 0; channel.PolyPressureOrigins[key] = null; }
            }
            RebuildPortNameIndex();
        }

        internal MidiState GetPortState(JsonValue selector)
        {
            string id = Automation.StringField(selector, "id"), name = Automation.StringField(selector, "name");
            if (string.IsNullOrEmpty(id) && string.IsNullOrEmpty(name)) return this;
            if (!string.IsNullOrEmpty(id))
                return _ports != null && _ports.TryGetValue(id, out Port port) && port.Connected ? port.State : null;
            if (_portInventory != null)
            {
                if (!_portInventory.TryGetValue(name, out id) || id == null) return null;
                return _ports != null && _ports.TryGetValue(id, out Port port) && port.Connected ? port.State : null;
            }
            return _portsByName != null && _portsByName.TryGetValue(name, out MidiState state) ? state : null;
        }

        public void SetPortInventory(IEnumerable<MidiPortInfo> ports)
        {
            _portInventory = new Dictionary<string, string>();
            if (ports == null) return;
            foreach (var port in ports)
            {
                if (port == null || !port.Connected || string.IsNullOrEmpty(port.Id) || string.IsNullOrEmpty(port.Name)) continue;
                if (!_portInventory.TryGetValue(port.Name, out string previous) || previous == port.Id)
                    _portInventory[port.Name] = port.Id;
                else _portInventory[port.Name] = null;
            }
        }

        public IReadOnlyList<MidiPortInfo> GetPorts()
        {
            var result = new List<MidiPortInfo>();
            if (_ports != null) foreach (var entry in _ports)
                result.Add(new MidiPortInfo { Id = entry.Key, Name = entry.Value.Name, Connected = entry.Value.Connected });
            return result;
        }

        private void RebuildPortNameIndex()
        {
            if (_portsByName == null) return;
            _portsByName.Clear();
            foreach (Port port in _ports.Values)
            {
                if (!port.Connected || string.IsNullOrEmpty(port.Name)) continue;
                if (_portsByName.ContainsKey(port.Name)) _portsByName[port.Name] = null;
                else _portsByName.Add(port.Name, port.State);
            }
        }

        public MidiNote GetZoneVoice(int zone, int? members = null)
        {
            if ((zone != 0 && zone != 1) || (members.HasValue && (members < 1 || members > 15))) return null;
            MidiNote newest = null;
            void Consider(MidiNote note) { if (note != null && (newest == null || note.Order > newest.Order)) newest = note; }
            if (_ports != null)
            {
                Consider(_unscopedState.GetZoneVoice(zone, members));
                foreach (Port port in _ports.Values) if (port.Connected) Consider(port.State.GetZoneVoice(zone, members));
                // Existing hosts may write GetChannel().NoteOn directly. Only untagged
                // notes enter this compatibility scope; message-routed notes resolve per port.
                Consider(FindZoneVoice(zone, members, true));
            }
            else Consider(FindZoneVoice(zone, members, false));
            return newest;
        }

        private MidiNote FindZoneVoice(int zone, int? members, bool directOnly)
        {
            int count = members ?? (zone == 0 ? LowerZoneMembers : UpperZoneMembers) ?? 15;
            int first = zone == 0 ? 2 : 16 - count, last = zone == 0 ? 1 + count : 15;
            MidiNote newest = null;
            for (int index = first; index <= last; index++)
                foreach (MidiNote note in _channels[index].HeldNotes.Values)
                {
                    if (directOnly && note.Origin != null) continue;
                    if (newest == null || note.Order > newest.Order)
                        newest = new MidiNote { Key = note.Key, Velocity = note.Velocity,
                            TimeMilliseconds = note.TimeMilliseconds, Order = note.Order,
                            Origin = note.Origin, Channel = _channels[index], ChannelNumber = index };
                }
            return newest;
        }

        private List<int> ConfigureMpeZone(int master, int count)
        {
            var changed = new List<int>();
            if ((master != 1 && master != 16) || count > 15) return changed;
            int previousLower = LowerZoneMembers ?? 0, previousUpper = UpperZoneMembers ?? 0;
            if (master == 1)
            {
                LowerZoneMembers = count; UpperZoneMembers = UpperZoneMembers ?? 0;
                if (count > 0 && count + UpperZoneMembers > 14) UpperZoneMembers = Math.Max(0, 14 - count);
            }
            else
            {
                UpperZoneMembers = count; LowerZoneMembers = LowerZoneMembers ?? 0;
                if (count > 0 && count + LowerZoneMembers > 14) LowerZoneMembers = Math.Max(0, 14 - count);
            }
            int Owner(int lower, int upper, int channel)
            {
                if (lower > 0 && channel == 1) return 1;
                if (upper > 0 && channel == 16) return 2;
                if (lower > 0 && channel >= 2 && channel <= lower + 1) return 3;
                if (upper > 0 && channel >= 16 - upper && channel <= 15) return 4;
                return 0;
            }
            for (int n = 1; n <= 16; n++)
            {
                if (Owner(previousLower, previousUpper, n) == Owner(LowerZoneMembers ?? 0, UpperZoneMembers ?? 0, n)) continue;
                changed.Add(n);
                var channel = _channels[n];
                var nrpn = channel.NrpnSelector; var rpn = channel.RpnSelector; string family = channel.ParameterFamily;
                var selectorBytes = new byte[4]; Array.Copy(channel.Cc, 98, selectorBytes, 0, 4);
                channel.ClearNotes(); channel.ResetControllers();
                channel.NrpnSelector = nrpn; channel.RpnSelector = rpn; channel.ParameterFamily = family;
                Array.Copy(selectorBytes, 0, channel.Cc, 98, 4); channel.Cc[74] = 64;
            }
            return changed;
        }

        private static void ClearNoteOrigin(MidiChannelState channel, object origin)
        {
            foreach (int key in new List<int>(channel.HeldNotes.Keys))
                if (Equals(channel.HeldNotes[key].Origin, origin)) { channel.Keys[key] = 0; channel.HeldNotes.Remove(key); }
            if (!channel.HeldNotes.ContainsKey(channel.Key)) channel.Gate = 0;
        }

        private static void CopyControllerReset(MidiChannelState channel, MidiChannelState source, object origin, bool resetTimbre = false)
        {
            for (int cc = 0; cc < 128; cc++)
            {
                if ((MidiChannelState.RetainedControllers.Contains(cc) && !(resetTimbre && cc == 74)) ||
                    (channel.CcOrigins[cc] != null && !Equals(channel.CcOrigins[cc], origin))) continue;
                channel.Cc[cc] = source.Cc[cc]; channel.CcOrigins[cc] = origin;
            }
            for (int cc = 0; cc < 32; cc++)
            {
                if (channel.Cc14Origins[cc] != null && !Equals(channel.Cc14Origins[cc], origin)) continue;
                channel.Cc14[cc] = source.Cc14[cc]; channel.Cc14Origins[cc] = origin;
            }
            if (channel.PitchBendOrigin == null || Equals(channel.PitchBendOrigin, origin)) channel.PitchBend = 8192;
            if (channel.PressureOrigin == null || Equals(channel.PressureOrigin, origin)) channel.Pressure = 0;
            for (int key = 0; key < 128; key++)
                if (Equals(channel.PolyPressureOrigins[key], origin)) channel.PolyPressure[key] = 0;
        }

        /// <summary>Route host-captured MIDI bytes through isolated source and aggregate state.</summary>
        public MidiParameterChange HandleMessage(byte[] data, string portId = null, string portName = null,
            double? timestampMilliseconds = null)
        {
            if (data == null || data.Length < 1) return null;
            MidiState sourceState = _ports != null ? (portId != null ? RegisterPort(portId, portName) : _unscopedState) : null;
            if (portId != null && _ports != null && sourceState == null) return null;
            MidiParameterChange change = sourceState?.HandleMessage(data, timestampMilliseconds: timestampMilliseconds);
            int status = data[0];
            if (status == 0xf8) { ClockCount++; return null; }
            int type = status & 0xf0, number = (status & 0x0f) + 1;
            if (data.Length < 2 || data[1] > 127 || (type != 0xd0 && (data.Length < 3 || data[2] > 127))) return null;
            int key = data[1], velocity = data.Length > 2 ? data[2] : 0;
            var channel = GetChannel(number); var source = sourceState?.GetChannel(number);
            object origin = (object)portId ?? UnscopedOrigin;
            if (type == 0xe0) { channel.PitchBend = key | (velocity << 7); channel.PitchBendOrigin = origin; return null; }
            if (type == 0xd0) { channel.Pressure = key; channel.PressureOrigin = origin; return null; }
            if (type == 0xa0) { channel.PolyPressure[key] = (byte)velocity; channel.PolyPressureOrigins[key] = origin; return null; }
            if (type == 0xb0)
            {
                if (source == null)
                {
                    change = channel.ControlChange(key, velocity);
                    if (change?.Family == "rpn" && change.Parameter == 6 && key == 6)
                        change.ResetChannels = ConfigureMpeZone(number, velocity);
                    return change;
                }
                channel.Cc[key] = source.Cc[key]; channel.CcOrigins[key] = origin;
                if (key < 64) { int msb = key & 31; channel.Cc14[msb] = source.Cc14[msb]; channel.Cc14Origins[msb] = origin; }
                if (change != null)
                {
                    (change.Family == "nrpn" ? channel.Nrpn : channel.Rpn)[change.Parameter] = change.Value;
                    (change.Family == "nrpn" ? channel.NrpnOrigins : channel.RpnOrigins)[change.Parameter] = origin;
                    if (change.ResetChannels != null) foreach (int index in change.ResetChannels)
                    { ClearNoteOrigin(_channels[index], origin); CopyControllerReset(_channels[index], sourceState._channels[index], origin, true); }
                }
                if (key == 120 || key == 123)
                {
                    ClearNoteOrigin(channel, origin);
                    for (int note = 0; note < 128; note++) if (Equals(channel.PolyPressureOrigins[note], origin)) channel.PolyPressure[note] = 0;
                }
                if (key == 121) CopyControllerReset(channel, source, origin);
                return change;
            }
            if (type == 0x90 && velocity > 0)
            {
                MidiNote sourceNote = null; source?.HeldNotes.TryGetValue(key, out sourceNote);
                channel.ApplyNoteOn(key, velocity, timestampMilliseconds, sourceNote, origin);
            }
            else if (type == 0x80 || (type == 0x90 && velocity == 0))
            {
                if (source == null) channel.NoteOff(key);
                else
                {
                    channel.Gate = 0;
                    if (channel.HeldNotes.TryGetValue(key, out MidiNote note) && Equals(note.Origin, origin))
                    { channel.Keys[key] = 0; channel.HeldNotes.Remove(key); }
                    if (Equals(channel.PolyPressureOrigins[key], origin)) channel.PolyPressure[key] = 0;
                }
            }
            return null;
        }

        public void Reset()
        {
            for (int i = 1; i <= 16; i++) _channels[i].Reset();
            ClockCount = 0; LowerZoneMembers = UpperZoneMembers = null;
            _unscopedState?.Reset();
            if (_ports != null) foreach (Port port in _ports.Values) port.State.Reset();
        }
    }

    public sealed class AudioDeviceInfo
    {
        public string Id { get; set; }
        public string Name { get; set; }
        public bool Connected { get; set; } = true;
        public int ChannelCount { get; set; }
    }

    public sealed class AudioState
    {
        private sealed class Device
        {
            public string Name;
            public bool Connected;
            public readonly Dictionary<int, AudioState> Channels =
                new Dictionary<int, AudioState>();
        }

        private readonly Dictionary<string, Device> _devices;
        private readonly Dictionary<string, Device> _devicesByName;
        private Dictionary<string, string> _deviceInventory;
        private readonly Dictionary<int, AudioState> _defaultChannels;
        private bool _defaultConnected;

        public double Low { get; set; }
        public double Mid { get; set; }
        public double High { get; set; }
        public double Vol { get; set; }
        public double Raw { get; private set; }
        public bool RawReady { get; private set; }

        public AudioState() : this(true) { }

        private AudioState(bool deviceRegistry)
        {
            if (deviceRegistry)
            {
                _devices = new Dictionary<string, Device>();
                _devicesByName = new Dictionary<string, Device>();
                _defaultChannels = new Dictionary<int, AudioState>();
            }
        }

        public void SetDeviceInventory(IEnumerable<AudioDeviceInfo> devices)
        {
            _deviceInventory = new Dictionary<string, string>();
            if (devices == null) return;
            foreach (var device in devices)
            {
                if (device == null || !device.Connected || string.IsNullOrEmpty(device.Id) || string.IsNullOrEmpty(device.Name)) continue;
                if (!_deviceInventory.TryGetValue(device.Name, out string previous) || previous == device.Id)
                    _deviceInventory[device.Name] = device.Id;
                else _deviceInventory[device.Name] = null;
            }
        }

        public IReadOnlyDictionary<int, AudioState> RegisterDefaultChannels(int channelCount)
        {
            if (_defaultChannels == null || channelCount < 1 || channelCount > 32) return null;
            _defaultConnected = true;
            for (int channel = 1; channel <= channelCount; channel++)
                if (!_defaultChannels.ContainsKey(channel)) _defaultChannels.Add(channel, new AudioState(false));
            foreach (int channel in new List<int>(_defaultChannels.Keys))
                if (channel > channelCount) { _defaultChannels[channel].Reset(); _defaultChannels.Remove(channel); }
            return _defaultChannels;
        }

        public AudioState GetDefaultChannelState(int channel)
        {
            return _defaultConnected && channel >= 1 && channel <= 32 && _defaultChannels != null
                && _defaultChannels.TryGetValue(channel, out AudioState state) ? state : null;
        }

        public void DisconnectDefaultInput()
        {
            _defaultConnected = false;
            if (_defaultChannels != null) foreach (AudioState state in _defaultChannels.Values) state.Reset();
        }

        public IReadOnlyList<AudioDeviceInfo> GetDevices()
        {
            var result = new List<AudioDeviceInfo>();
            if (_devices != null) foreach (var entry in _devices)
                result.Add(new AudioDeviceInfo { Id = entry.Key, Name = entry.Value.Name,
                    Connected = entry.Value.Connected, ChannelCount = entry.Value.Channels.Count });
            return result;
        }

        public void SetBands(double low, double mid, double high)
        {
            Low = Clamp01(low);
            Mid = Clamp01(mid);
            High = Clamp01(high);
            Vol = (Low + Mid + High) / 3.0;
        }

        public void SetRaw(double value)
        {
            Raw = IsFinite(value) ? Math.Max(-1, Math.Min(1, value)) : 0;
            RawReady = true;
        }

        public void SetRawUnavailable()
        {
            Raw = 0;
            RawReady = false;
        }

        public void RegisterDevice(string id, string name, int channelCount)
        {
            if (_devices == null || string.IsNullOrEmpty(id)) return;
            if (channelCount < 1) channelCount = 1;
            Device device;
            if (!_devices.TryGetValue(id, out device))
            {
                device = new Device();
                _devices.Add(id, device);
            }
            device.Name = name ?? "";
            device.Connected = true;
            for (int channel = 1; channel <= channelCount; channel++)
                if (!device.Channels.ContainsKey(channel))
                    device.Channels.Add(channel, new AudioState(false));
            var stale = new List<int>();
            foreach (int channel in device.Channels.Keys)
                if (channel > channelCount) stale.Add(channel);
            foreach (int channel in stale) { device.Channels[channel].Reset(); device.Channels.Remove(channel); }
            RebuildDeviceNameIndex();
        }

        public bool SetChannelValues(string id, int channel, double? low = null,
            double? mid = null, double? high = null, double? vol = null,
            double? raw = null)
        {
            Device device;
            AudioState state;
            if (_devices == null || !_devices.TryGetValue(id, out device) ||
                !device.Connected || !device.Channels.TryGetValue(channel, out state))
                return false;
            if (low.HasValue && IsFinite(low.Value)) state.Low = Clamp01(low.Value);
            if (mid.HasValue && IsFinite(mid.Value)) state.Mid = Clamp01(mid.Value);
            if (high.HasValue && IsFinite(high.Value)) state.High = Clamp01(high.Value);
            if (vol.HasValue && IsFinite(vol.Value)) state.Vol = Clamp01(vol.Value);
            if (raw.HasValue && IsFinite(raw.Value)) state.SetRaw(raw.Value);
            return true;
        }

        public void SetDeviceRawUnavailable(string id)
        {
            Device device;
            if (_devices == null || !_devices.TryGetValue(id, out device)) return;
            foreach (AudioState state in device.Channels.Values) state.SetRawUnavailable();
        }

        public void DisconnectDevice(string id)
        {
            Device device;
            if (_devices == null || !_devices.TryGetValue(id, out device)) return;
            device.Connected = false;
            foreach (AudioState state in device.Channels.Values) state.Reset();
            RebuildDeviceNameIndex();
        }

        internal AudioState GetDeviceChannelState(JsonValue selector)
        {
            if (!Automation.HasAudioSelector(selector)) return this;
            if (!Automation.ValidAudioSelector(selector)) return null;
            string id = Automation.StringField(selector, "id");
            string name = Automation.StringField(selector, "name");
            int channel = (int)Automation.NumberField(selector, "channel").Value;
            if (string.IsNullOrEmpty(id) && string.IsNullOrEmpty(name)) return GetDefaultChannelState(channel);
            Device device = null;
            if (!string.IsNullOrEmpty(id))
            {
                if (_devices != null) _devices.TryGetValue(id, out device);
            }
            else if (_deviceInventory != null)
            {
                if (_deviceInventory.TryGetValue(name, out string selectedId) && selectedId != null && _devices != null)
                    _devices.TryGetValue(selectedId, out device);
            }
            else if (_devicesByName != null) _devicesByName.TryGetValue(name, out device);
            if (device == null || !device.Connected) return null;
            return device.Channels.TryGetValue(channel, out AudioState state) ? state : null;
        }

        public void ResetAggregate()
        {
            Low = Mid = High = Vol = Raw = 0;
            RawReady = false;
        }

        public void Reset()
        {
            ResetAggregate();
            if (_defaultChannels != null) foreach (AudioState state in _defaultChannels.Values) state.Reset();
            if (_devices != null)
                foreach (Device device in _devices.Values)
                    foreach (AudioState state in device.Channels.Values) state.Reset();
        }

        private void RebuildDeviceNameIndex()
        {
            if (_devicesByName == null) return;
            _devicesByName.Clear();
            var ambiguous = new HashSet<string>();
            foreach (Device device in _devices.Values)
            {
                if (!device.Connected || string.IsNullOrEmpty(device.Name)) continue;
                if (_devicesByName.ContainsKey(device.Name))
                {
                    _devicesByName.Remove(device.Name);
                    ambiguous.Add(device.Name);
                }
                else if (!ambiguous.Contains(device.Name))
                    _devicesByName.Add(device.Name, device);
            }
        }

        private static double Clamp01(double value)
        {
            return IsFinite(value) ? Math.Max(0, Math.Min(1, value)) : 0;
        }

        private static bool IsFinite(double value)
        {
            return !double.IsNaN(value) && !double.IsInfinity(value);
        }
    }
}
