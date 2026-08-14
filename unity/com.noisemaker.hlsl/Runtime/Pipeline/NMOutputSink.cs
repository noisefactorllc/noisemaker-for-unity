using System;
using System.Collections.Generic;
using System.Runtime.CompilerServices;
using UnityEngine;

namespace Noisemaker.Hlsl
{
    public enum NMOutputFormat
    {
        Rgba8Unorm
    }

    public enum NMOutputColorSpace
    {
        Srgb,
        DisplayP3
    }

    public enum NMOutputAlphaMode
    {
        Straight,
        Opaque,
        Premultiplied
    }

    public sealed class NMOutputDescriptor
    {
        public int Width { get; private set; }
        public int Height { get; private set; }
        public NMOutputFormat Format { get; private set; }
        public NMOutputColorSpace ColorSpace { get; private set; }
        public NMOutputAlphaMode AlphaMode { get; private set; }
        public double Fps { get; private set; }

        public NMOutputDescriptor(int width, int height, NMOutputAlphaMode alphaMode,
            NMOutputFormat format = NMOutputFormat.Rgba8Unorm,
            NMOutputColorSpace colorSpace = NMOutputColorSpace.Srgb,
            double fps = 60.0)
        {
            if (width <= 0) throw new ArgumentOutOfRangeException(nameof(width));
            if (height <= 0) throw new ArgumentOutOfRangeException(nameof(height));
            if (double.IsNaN(fps) || double.IsInfinity(fps) || fps <= 0.0)
                throw new ArgumentOutOfRangeException(nameof(fps));
            if (!Enum.IsDefined(typeof(NMOutputFormat), format))
                throw new ArgumentOutOfRangeException(nameof(format));
            if (!Enum.IsDefined(typeof(NMOutputColorSpace), colorSpace))
                throw new ArgumentOutOfRangeException(nameof(colorSpace));
            if (!Enum.IsDefined(typeof(NMOutputAlphaMode), alphaMode))
                throw new ArgumentOutOfRangeException(nameof(alphaMode));
            Width = width;
            Height = height;
            Format = format;
            ColorSpace = colorSpace;
            AlphaMode = alphaMode;
            Fps = fps;
        }
    }

    public sealed class NMOutputCloseOptions
    {
        public bool BackendLost { get; private set; }

        public NMOutputCloseOptions(bool backendLost = false)
        {
            BackendLost = backendLost;
        }
    }

    public interface INMOutputSink
    {
        void Configure(NMOutputDescriptor descriptor);
        bool Submit(RenderTexture texture, double timestampMilliseconds);
        void Close(NMOutputCloseOptions options = null);
    }

    public sealed class NMSinkStats
    {
        public int Accepted { get; internal set; }
        public int Dropped { get; internal set; }
        public int Failed { get; internal set; }
    }

    public sealed class NMSinkManager
    {
        private sealed class ReferenceComparer : IEqualityComparer<INMOutputSink>
        {
            public static readonly ReferenceComparer Instance = new ReferenceComparer();

            public bool Equals(INMOutputSink left, INMOutputSink right)
            {
                return ReferenceEquals(left, right);
            }

            public int GetHashCode(INMOutputSink value)
            {
                return RuntimeHelpers.GetHashCode(value);
            }
        }

        private sealed class Registration
        {
            public INMOutputSink Sink;
            public NMSinkStats Stats;
            public bool Active;
        }

        private readonly Action<Exception, INMOutputSink> _onError;
        private readonly List<Registration> _registrations = new List<Registration>();
        private readonly Dictionary<INMOutputSink, Registration> _registrationsBySink =
            new Dictionary<INMOutputSink, Registration>(ReferenceComparer.Instance);
        private readonly Dictionary<INMOutputSink, NMSinkStats> _stats =
            new Dictionary<INMOutputSink, NMSinkStats>(ReferenceComparer.Instance);

        private NMOutputDescriptor _descriptor;
        private bool _configured;
        private bool _closed;
        private int _iterationDepth;
        private bool _hasTombstones;

        public IReadOnlyDictionary<INMOutputSink, NMSinkStats> Stats { get { return _stats; } }

        public NMSinkManager(Action<Exception, INMOutputSink> onError = null)
        {
            _onError = onError;
        }

        public Action Add(INMOutputSink sink)
        {
            if (_closed) throw new InvalidOperationException("Sink manager is closed");
            if (sink == null) throw new ArgumentNullException(nameof(sink));
            if (_registrationsBySink.ContainsKey(sink))
                throw new InvalidOperationException("Sink is already registered");

            if (_configured) sink.Configure(_descriptor);

            var registration = new Registration
            {
                Sink = sink,
                Stats = new NMSinkStats(),
                Active = true
            };
            _registrations.Add(registration);
            _registrationsBySink.Add(sink, registration);
            _stats.Add(sink, registration.Stats);

            bool removed = false;
            return () =>
            {
                if (removed) return;
                removed = true;
                RemoveRegistration(registration);
            };
        }

        public void Remove(INMOutputSink sink)
        {
            if (sink == null) return;
            Registration registration;
            if (_registrationsBySink.TryGetValue(sink, out registration))
                RemoveRegistration(registration);
        }

        public void Configure(NMOutputDescriptor descriptor)
        {
            if (_closed) return;
            if (descriptor == null) throw new ArgumentNullException(nameof(descriptor));
            _descriptor = descriptor;
            _configured = true;

            _iterationDepth++;
            try
            {
                for (int i = 0; i < _registrations.Count; i++)
                {
                    Registration registration = _registrations[i];
                    if (!registration.Active) continue;
                    INMOutputSink sink = registration.Sink;
                    try
                    {
                        sink.Configure(descriptor);
                    }
                    catch (Exception error)
                    {
                        registration.Stats.Failed++;
                        Report(error, sink);
                    }
                }
            }
            finally
            {
                _iterationDepth--;
                if (_iterationDepth == 0) CompactRegistrations();
            }
        }

        public void Submit(RenderTexture texture, double timestampMilliseconds)
        {
            if (_closed) return;

            _iterationDepth++;
            try
            {
                for (int i = 0; i < _registrations.Count; i++)
                {
                    Registration registration = _registrations[i];
                    if (!registration.Active) continue;
                    INMOutputSink sink = registration.Sink;
                    bool accepted;
                    try
                    {
                        accepted = sink.Submit(texture, timestampMilliseconds);
                    }
                    catch (Exception error)
                    {
                        registration.Stats.Failed++;
                        Report(error, sink);
                        continue;
                    }

                    if (accepted) registration.Stats.Accepted++;
                    else registration.Stats.Dropped++;
                }
            }
            finally
            {
                _iterationDepth--;
                if (_iterationDepth == 0) CompactRegistrations();
            }
        }

        public void Close(NMOutputCloseOptions options = null)
        {
            if (_closed) return;
            _closed = true;

            var sinks = new List<INMOutputSink>(_registrations.Count);
            for (int i = 0; i < _registrations.Count; i++)
            {
                Registration registration = _registrations[i];
                if (!registration.Active) continue;
                registration.Active = false;
                sinks.Add(registration.Sink);
                registration.Sink = null;
            }
            _registrations.Clear();
            _registrationsBySink.Clear();
            _stats.Clear();
            _hasTombstones = false;

            Exception firstError = null;
            for (int i = 0; i < sinks.Count; i++)
            {
                try
                {
                    sinks[i].Close(options);
                }
                catch (Exception error)
                {
                    if (firstError == null) firstError = error;
                }
            }
            if (firstError != null) throw firstError;
        }

        private void RemoveRegistration(Registration registration)
        {
            if (registration == null || !registration.Active) return;
            INMOutputSink sink = registration.Sink;
            registration.Active = false;
            registration.Sink = null;
            _hasTombstones = true;

            Registration current;
            if (_registrationsBySink.TryGetValue(sink, out current) &&
                ReferenceEquals(current, registration))
            {
                _registrationsBySink.Remove(sink);
                _stats.Remove(sink);
            }

            try
            {
                sink.Close();
            }
            finally
            {
                if (_iterationDepth == 0) CompactRegistrations();
            }
        }

        private void CompactRegistrations()
        {
            if (!_hasTombstones) return;
            int write = 0;
            for (int read = 0; read < _registrations.Count; read++)
            {
                Registration registration = _registrations[read];
                if (!registration.Active) continue;
                _registrations[write++] = registration;
            }
            if (write < _registrations.Count)
                _registrations.RemoveRange(write, _registrations.Count - write);
            _hasTombstones = false;
        }

        private void Report(Exception error, INMOutputSink sink)
        {
            if (_onError == null) return;
            try
            {
                _onError(error, sink);
            }
            catch
            {
                // Error reporters cannot interrupt rendering or other sinks.
            }
        }
    }
}
