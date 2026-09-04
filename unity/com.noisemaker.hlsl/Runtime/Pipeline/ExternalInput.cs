using System;
using System.Collections.Generic;
using System.Diagnostics;
using Noisemaker.Hlsl.Compiler.Graph;

namespace Noisemaker.Hlsl
{
    public sealed class MidiChannelState
    {
        public int Key { get; set; }
        public int Velocity { get; set; }
        public int Gate { get; set; }
        public double TimeMilliseconds { get; set; }

        public void NoteOn(int key, int velocity, double? timestampMilliseconds = null)
        {
            Key = key;
            Velocity = velocity;
            Gate = 1;
            TimeMilliseconds = timestampMilliseconds ?? CurrentMilliseconds();
        }

        public void NoteOff()
        {
            Gate = 0;
        }

        public void Reset()
        {
            Key = 0;
            Velocity = 0;
            Gate = 0;
            TimeMilliseconds = 0;
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

        private readonly MidiChannelState[] _channels = new MidiChannelState[17];
        private readonly Dictionary<string, Port> _ports;
        private readonly Dictionary<string, MidiState> _portsByName;

        public MidiState() : this(true) { }

        private MidiState(bool portRegistry)
        {
            for (int i = 1; i <= 16; i++) _channels[i] = new MidiChannelState();
            if (portRegistry)
            {
                _ports = new Dictionary<string, Port>();
                _portsByName = new Dictionary<string, MidiState>();
            }
        }

        public MidiChannelState GetChannel(int channel)
        {
            return channel >= 1 && channel <= 16 ? _channels[channel] : _channels[1];
        }

        public MidiState RegisterPort(string id, string name)
        {
            if (_ports == null || string.IsNullOrEmpty(id)) return null;
            Port port;
            if (!_ports.TryGetValue(id, out port))
            {
                port = new Port { State = new MidiState(false) };
                _ports.Add(id, port);
            }
            port.Name = name ?? "";
            port.Connected = true;
            RebuildPortNameIndex();
            return port.State;
        }

        public void DisconnectPort(string id)
        {
            if (_ports == null || string.IsNullOrEmpty(id)) return;
            Port port;
            if (!_ports.TryGetValue(id, out port)) return;
            port.Connected = false;
            port.State.Reset();
            RebuildPortNameIndex();
        }

        internal MidiState GetPortState(JsonValue selector)
        {
            string id = Automation.StringField(selector, "id");
            string name = Automation.StringField(selector, "name");
            if (string.IsNullOrEmpty(id) && string.IsNullOrEmpty(name)) return this;
            if (!string.IsNullOrEmpty(id))
            {
                Port port;
                return _ports != null && _ports.TryGetValue(id, out port) && port.Connected
                    ? port.State : null;
            }
            MidiState state;
            return _portsByName != null && _portsByName.TryGetValue(name, out state)
                ? state : null;
        }

        public void Reset()
        {
            for (int i = 1; i <= 16; i++) _channels[i].Reset();
            if (_ports != null)
                foreach (Port port in _ports.Values) port.State.Reset();
        }

        private void RebuildPortNameIndex()
        {
            if (_portsByName == null) return;
            _portsByName.Clear();
            var ambiguous = new HashSet<string>();
            foreach (Port port in _ports.Values)
            {
                if (!port.Connected || string.IsNullOrEmpty(port.Name)) continue;
                if (_portsByName.ContainsKey(port.Name))
                {
                    _portsByName.Remove(port.Name);
                    ambiguous.Add(port.Name);
                }
                else if (!ambiguous.Contains(port.Name))
                    _portsByName.Add(port.Name, port.State);
            }
        }
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
            }
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
            foreach (int channel in stale) device.Channels.Remove(channel);
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
            string id = Automation.StringField(selector, "id");
            string name = Automation.StringField(selector, "name");
            double? channelValue = Automation.NumberField(selector, "channel");
            bool hasSelector = !string.IsNullOrEmpty(id) || !string.IsNullOrEmpty(name) ||
                channelValue.HasValue;
            if (!hasSelector) return this;
            if (!channelValue.HasValue || channelValue.Value < 1 ||
                channelValue.Value != Math.Floor(channelValue.Value)) return null;

            Device device = null;
            if (!string.IsNullOrEmpty(id))
            {
                if (_devices != null) _devices.TryGetValue(id, out device);
            }
            else if (!string.IsNullOrEmpty(name) && _devicesByName != null)
                _devicesByName.TryGetValue(name, out device);
            if (device == null || !device.Connected) return null;
            AudioState state;
            return device.Channels.TryGetValue((int)channelValue.Value, out state) ? state : null;
        }

        public void Reset()
        {
            Low = Mid = High = Vol = Raw = 0;
            RawReady = false;
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
