using System;
using UnityEngine;

namespace Noisemaker.Hlsl
{
    public sealed class NMFrameExportFrame
    {
        public int Width { get; private set; }
        public int Height { get; private set; }
        public int RowStride { get; private set; }
        public byte[] Data { get; private set; }

        public NMFrameExportFrame(int width, int height, int rowStride, byte[] data)
        {
            if (width <= 0) throw new ArgumentOutOfRangeException(nameof(width));
            if (height <= 0) throw new ArgumentOutOfRangeException(nameof(height));
            if (rowStride < checked(width * 4))
                throw new ArgumentOutOfRangeException(nameof(rowStride));
            if (data == null) throw new ArgumentNullException(nameof(data));
            if (data.Length < checked(rowStride * height))
                throw new ArgumentException("Frame data is smaller than its layout", nameof(data));
            Width = width;
            Height = height;
            RowStride = rowStride;
            Data = data;
        }
    }

    public interface INMFrameExportAdapter
    {
        object CreateSlot(int index, NMOutputDescriptor descriptor);
        void Begin(object adapterSlot, RenderTexture texture, double timestampMilliseconds);
        bool Poll(object adapterSlot);
        NMFrameExportFrame Read(object adapterSlot);
        void DestroySlot(object adapterSlot);
    }

    public delegate void NMFrameExportCallback(NMFrameExportFrame frame,
        double timestampMilliseconds, object context);

    public sealed class NMFrameExportStats
    {
        public int Accepted { get; internal set; }
        public int Dropped { get; internal set; }
        public int Completed { get; internal set; }
        public int Failed { get; internal set; }
    }

    public sealed class NMFrameExportQueue
    {
        private sealed class SlotRecord
        {
            public object AdapterSlot;
            public bool Created;
            public bool Pending;
            public RenderTexture Texture;
            public double Timestamp;
            public NMFrameExportCallback OnFrame;
            public object Context;
        }

        private INMFrameExportAdapter _adapter;
        private readonly Action<Exception> _onError;
        private readonly SlotRecord[] _slots;
        private bool _configured;
        private bool _closed;

        public NMFrameExportStats Stats { get; private set; }

        public bool Available
        {
            get
            {
                if (!_configured || _closed) return false;
                for (int i = 0; i < _slots.Length; i++)
                    if (!_slots[i].Pending) return true;
                return false;
            }
        }

        public NMFrameExportQueue(INMFrameExportAdapter adapter, int slots = 3,
            Action<Exception> onError = null)
        {
            if (adapter == null) throw new ArgumentNullException(nameof(adapter));
            if (slots < 2 || slots > 8)
                throw new ArgumentOutOfRangeException(nameof(slots),
                    "Frame export slots must be from 2 through 8");
            _adapter = adapter;
            _onError = onError;
            _slots = new SlotRecord[slots];
            for (int i = 0; i < slots; i++) _slots[i] = new SlotRecord();
            Stats = new NMFrameExportStats();
        }

        public void Configure(NMOutputDescriptor descriptor)
        {
            if (_closed) return;
            if (descriptor == null) throw new ArgumentNullException(nameof(descriptor));

            Exception destroyError = DestroySlots();
            _configured = false;
            if (destroyError != null) throw destroyError;

            try
            {
                for (int i = 0; i < _slots.Length; i++)
                {
                    SlotRecord record = _slots[i];
                    record.AdapterSlot = _adapter.CreateSlot(i, descriptor);
                    if (record.AdapterSlot == null)
                        throw new InvalidOperationException("Frame export adapter returned a null slot");
                    record.Created = true;
                }
            }
            catch
            {
                Exception cleanupError = DestroySlots();
                if (cleanupError != null) Report(cleanupError);
                throw;
            }
            _configured = true;
        }

        public bool Enqueue(RenderTexture texture, double timestampMilliseconds,
            NMFrameExportCallback onFrame, object context = null)
        {
            if (onFrame == null) throw new ArgumentNullException(nameof(onFrame));
            if (!_configured || _closed)
            {
                Stats.Dropped++;
                return false;
            }

            SlotRecord record = null;
            for (int i = 0; i < _slots.Length; i++)
            {
                if (!_slots[i].Pending)
                {
                    record = _slots[i];
                    break;
                }
            }
            if (record == null)
            {
                Stats.Dropped++;
                return false;
            }

            record.Pending = true;
            record.Texture = texture;
            record.Timestamp = timestampMilliseconds;
            record.OnFrame = onFrame;
            record.Context = context;
            try
            {
                _adapter.Begin(record.AdapterSlot, texture, timestampMilliseconds);
            }
            catch (Exception error)
            {
                Release(record);
                Stats.Failed++;
                Report(error);
                return false;
            }

            Stats.Accepted++;
            return true;
        }

        public void Poll()
        {
            if (!_configured || _closed) return;

            for (int i = 0; i < _slots.Length; i++)
            {
                SlotRecord record = _slots[i];
                if (!record.Pending) continue;

                NMFrameExportFrame frame;
                double timestamp;
                NMFrameExportCallback onFrame;
                object context;
                try
                {
                    if (!_adapter.Poll(record.AdapterSlot)) continue;
                    frame = _adapter.Read(record.AdapterSlot);
                    if (frame == null)
                        throw new InvalidOperationException("Frame export adapter returned a null frame");
                    timestamp = record.Timestamp;
                    onFrame = record.OnFrame;
                    context = record.Context;
                }
                catch (Exception error)
                {
                    Release(record);
                    Stats.Failed++;
                    Report(error);
                    continue;
                }

                Release(record);
                try
                {
                    onFrame(frame, timestamp, context);
                    Stats.Completed++;
                }
                catch (Exception error)
                {
                    Stats.Failed++;
                    Report(error);
                }
            }
        }

        public void Close(NMOutputCloseOptions options = null)
        {
            if (_closed) return;
            _closed = true;
            _configured = false;

            Exception destroyError = null;
            if (options != null && options.BackendLost) AbandonSlots();
            else destroyError = DestroySlots();
            _adapter = null;
            if (destroyError != null) throw destroyError;
        }

        private static void Release(SlotRecord record)
        {
            record.Pending = false;
            record.Texture = null;
            record.Timestamp = 0.0;
            record.OnFrame = null;
            record.Context = null;
        }

        private Exception DestroySlots()
        {
            Exception firstError = null;
            for (int i = 0; i < _slots.Length; i++)
            {
                SlotRecord record = _slots[i];
                if (!record.Created) continue;
                object adapterSlot = record.AdapterSlot;
                record.Created = false;
                record.AdapterSlot = null;
                Release(record);
                try
                {
                    _adapter.DestroySlot(adapterSlot);
                }
                catch (Exception error)
                {
                    if (firstError == null) firstError = error;
                }
            }
            return firstError;
        }

        private void AbandonSlots()
        {
            for (int i = 0; i < _slots.Length; i++)
            {
                SlotRecord record = _slots[i];
                record.Created = false;
                record.AdapterSlot = null;
                Release(record);
            }
        }

        private void Report(Exception error)
        {
            if (_onError == null) return;
            try
            {
                _onError(error);
            }
            catch
            {
                // Error reporters cannot interrupt queue progress.
            }
        }
    }
}
