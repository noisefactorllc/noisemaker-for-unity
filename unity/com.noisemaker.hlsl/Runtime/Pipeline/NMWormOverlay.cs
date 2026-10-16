using System;
using System.Threading;
using UnityEngine;

namespace Noisemaker.Hlsl
{
    // CPU counterpart of shaders/src/cpu/wormTracer.js for the three effects
    // whose blend passes sample a canvas-generated overlayTex.
    internal static class NMWormOverlay
    {
        private const double Tau = Math.PI * 2.0;
        private const int CoverageSamples = 8;

        private struct Ink
        {
            public double R, G, B, A;
            public Ink(double r, double g, double b, double a)
            {
                R = r / 255.0; G = g / 255.0; B = b / 255.0; A = a;
            }
        }

        private struct Worm
        {
            public double X, Y, Stride, Rotation;
            public Ink Color;
        }

        // JS uses Number arithmetic before >>> 0, including its 53-bit rounding.
        private struct SeededRng
        {
            private uint _state;

            public SeededRng(double seed)
            {
                _state = Uint32(Uint32(seed) * 747796405.0 + 2891336453.0);
            }

            private static uint Uint32(double value)
            {
                double wrapped = value % 4294967296.0;
                if (wrapped < 0) wrapped += 4294967296.0;
                return (uint)wrapped;
            }

            public uint Next()
            {
                _state = Uint32(_state * 747796405.0 + 2891336453.0);
                int mixed = unchecked((int)((_state >> (int)((_state >> 28) + 4)) ^ _state));
                uint word = Uint32(mixed * 277803737.0);
                return (word >> 22) ^ word;
            }

            public double Float() { return Next() / 4294967295.0; }

            public double Normal(double mean, double std)
            {
                double u1 = Math.Max(Float(), 1e-10);
                double u2 = Float();
                return mean + std * Math.Sqrt(-2.0 * Math.Log(u1)) * Math.Cos(Tau * u2);
            }
        }

        public static bool Supports(string effectKey)
        {
            return effectKey == "filter.fibers" || effectKey == "filter.scratches" ||
                   effectKey == "filter.strayHair";
        }

        public static Color32[] Render(string effectKey, int width, int height,
            double density, double seed, CancellationToken cancellation = default(CancellationToken))
        {
            cancellation.ThrowIfCancellationRequested();
            // Keep the raster premultiplied in one byte buffer. The reference's
            // canvas is 8-bit, and this avoids a 512 MiB double raster at 4K.
            var pixels = new Color32[checked(width * height)];
            int baseSeed = seed == 0.0 ? 1 : (int)seed;
            if (effectKey == "filter.fibers")
            {
                double scaledDensity = 0.5 + density * 2.0;
                for (int layer = 0; layer < 4; layer++)
                {
                    int layerSeed = baseSeed * 1000 + layer * 137;
                    Trace(pixels, width, height, layerSeed, scaledDensity,
                        5 + layerSeed % 5, 0.75, 0.125, 1.0, 0, 4, 0,
                        Math.Max(1.5, width / 384.0), cancellation);
                }
            }
            else if (effectKey == "filter.scratches")
            {
                for (int layer = 0; layer < 4; layer++)
                {
                    int layerSeed = baseSeed * 1000 + layer * 251;
                    Trace(pixels, width, height, layerSeed, 0.1 + density * 0.4,
                        0.125 + (layerSeed % 50) / 400.0, 0.75, 0.5,
                        2 + layerSeed % 3, layerSeed % 2 == 0 ? 1 : 2,
                        2 + layerSeed % 3, 1, Math.Max(0.5, width / 1024.0), cancellation);
                }
            }
            else if (effectKey == "filter.strayHair")
            {
                int layerSeed = baseSeed * 1000 + 42;
                Trace(pixels, width, height, layerSeed, 0.001 + density * 0.004,
                    5 + layerSeed % 45, 0.5, 0.25, 8 + layerSeed % 8, 2, 4, 2,
                    Math.Max(1.0, width / 400.0), cancellation);
            }
            else throw new ArgumentException("Unsupported CPU overlay: " + effectKey);

            for (int i = 0; i < pixels.Length; i++)
            {
                Color32 p = pixels[i];
                if (p.a == 0) continue;
                pixels[i] = new Color32(
                    Byte(p.r / (double)p.a), Byte(p.g / (double)p.a),
                    Byte(p.b / (double)p.a), p.a);
            }
            return pixels;
        }

        private static byte Byte(double value)
        {
            return (byte)Math.Max(0, Math.Min(255, Math.Floor(value * 255.0 + 0.5)));
        }

        private struct NoiseGrid
        {
            public int Width, Height, GridWidth;
            public double Freq;
            public float[] Grid;

            public float Sample(int x, int y)
            {
                double fx = (x / (double)Width) * Freq;
                double fy = (y / (double)Height) * Freq;
                int ix = (int)Math.Floor(fx), iy = (int)Math.Floor(fy);
                double dx = fx - ix, dy = fy - iy;
                double sx = dx * dx * (3.0 - 2.0 * dx);
                double sy = dy * dy * (3.0 - 2.0 * dy);
                double top = Grid[iy * GridWidth + ix] * (1.0 - sx) +
                    Grid[iy * GridWidth + ix + 1] * sx;
                double bottom = Grid[(iy + 1) * GridWidth + ix] * (1.0 - sx) +
                    Grid[(iy + 1) * GridWidth + ix + 1] * sx;
                return (float)(top * (1.0 - sy) + bottom * sy);
            }
        }

        private static NoiseGrid CreateNoiseGrid(int width, int height, double freq, int seed)
        {
            int gridWidth = (int)Math.Ceiling(freq) + 2;
            int gridHeight = gridWidth;
            var grid = new float[gridWidth * gridHeight];
            var rng = new SeededRng(seed * 31337.0);
            for (int i = 0; i < grid.Length; i++) grid[i] = (float)rng.Float();
            return new NoiseGrid { Width = width, Height = height,
                GridWidth = gridWidth, Freq = freq, Grid = grid };
        }

        // behavior: 0 chaotic, 1 obedient, 2 unruly.
        private static void Trace(Color32[] pixels, int width, int height, int seed,
            double density, double kink, double stride, double strideDeviation,
            double duration, int behavior, double flowFreq, int colorMode,
            double lineWidth, CancellationToken cancellation)
        {
            var rng = new SeededRng(seed);
            int minDim = Math.Min(width, height);
            int maxDim = Math.Max(width, height);
            double strideScale = maxDim / 1024.0;
            NoiseGrid field = CreateNoiseGrid(width, height, flowFreq, seed);
            int count = Math.Max(1, (int)Math.Floor(maxDim * density));
            double sharedRotation = rng.Float() * Tau;
            var worms = new Worm[count];
            for (int i = 0; i < count; i++)
            {
                var worm = new Worm {
                    X = rng.Float() * width,
                    Y = rng.Float() * height,
                    Stride = rng.Normal(stride, strideDeviation) * strideScale,
                    Rotation = behavior == 1 ? sharedRotation : rng.Float() * Tau
                };
                if (colorMode == 0)
                    worm.Color = new Ink(Math.Floor(rng.Float() * 200 + 55),
                        Math.Floor(rng.Float() * 200 + 55),
                        Math.Floor(rng.Float() * 200 + 55), 0.5);
                else if (colorMode == 1)
                    worm.Color = new Ink(255, 255, 255, 1.0);
                else
                    worm.Color = new Ink(Math.Floor(rng.Float() * 30),
                        Math.Floor(rng.Float() * 30),
                        Math.Floor(rng.Float() * 30), 0.666);
                worms[i] = worm;
            }

            int iterations = Math.Max(1, (int)Math.Floor(Math.Sqrt(minDim) * duration));
            foreach (Worm worm in worms)
            {
                cancellation.ThrowIfCancellationRequested();
                double wx = worm.X, wy = worm.Y;
                for (int iter = 0; iter < iterations; iter++)
                {
                    double t = iterations > 1 ? iter / (double)(iterations - 1) : 1.0;
                    double exposure = 1.0 - Math.Abs(1.0 - t * 2.0);
                    int fx = (int)Math.Floor(((wx % width) + width) % width);
                    int fy = (int)Math.Floor(((wy % height) + height) % height);
                    double angle = field.Sample(fx, fy) * Tau * kink +
                        (behavior == 1 ? sharedRotation : worm.Rotation);
                    double newX = wx + Math.Sin(angle) * worm.Stride;
                    double newY = wy + Math.Cos(angle) * worm.Stride;
                    Stroke(pixels, width, height, wx, wy, newX, newY,
                        lineWidth, worm.Color, exposure);
                    wx = newX; wy = newY;
                }
            }
        }

        private static void Stroke(Color32[] pixels, int width, int height,
            double x0, double y0, double x1, double y1, double lineWidth,
            Ink color, double exposure)
        {
            if (exposure <= 0) return;
            x0 = (float)x0; y0 = (float)y0;
            x1 = (float)x1; y1 = (float)y1;
            if (lineWidth <= 1.0)
            {
                Hairline(pixels, width, height, x0, y0, x1, y1,
                    color, exposure, lineWidth);
                return;
            }
            double radius = lineWidth * 0.5;
            Color32 paint = Premultiply(color, Byte(color.A * exposure));
            int left = Math.Max(0, (int)Math.Floor(Math.Min(x0, x1) - radius - 1));
            int right = Math.Min(width - 1, (int)Math.Ceiling(Math.Max(x0, x1) + radius + 1));
            int top = Math.Max(0, (int)Math.Floor(Math.Min(y0, y1) - radius - 1));
            int bottom = Math.Min(height - 1, (int)Math.Ceiling(Math.Max(y0, y1) + radius + 1));
            double vx = x1 - x0, vy = y1 - y0;
            double lengthSquared = vx * vx + vy * vy;
            for (int y = top; y <= bottom; y++)
            for (int x = left; x <= right; x++)
            {
                int covered = 0;
                for (int sy = 0; sy < CoverageSamples; sy++)
                for (int sx = 0; sx < CoverageSamples; sx++)
                {
                    double px = x + (sx + 0.5) / CoverageSamples;
                    double py = y + (sy + 0.5) / CoverageSamples;
                    double along = lengthSquared > 0 ?
                        Math.Max(0, Math.Min(1, ((px - x0) * vx + (py - y0) * vy) / lengthSquared)) : 0;
                    double dx = px - (x0 + along * vx);
                    double dy = py - (y0 + along * vy);
                    if (dx * dx + dy * dy <= radius * radius) covered++;
                }
                if (covered == 0) continue;
                int coverage = (covered * 255 + CoverageSamples * CoverageSamples / 2) /
                    (CoverageSamples * CoverageSamples);
                BlendCoverage(pixels, width, height, x, y, paint, coverage);
            }
        }

        // Canvas submits float32 endpoints. The software hairline scan converter
        // extends round caps by pi/8 and computes coverage in 26.6 / 16.16 space.
        private static void Hairline(Color32[] pixels, int width, int height,
            double x0, double y0, double x1, double y1, Ink color, double opacity,
            double lineWidth)
        {
            float vx = (float)(x1 - x0), vy = (float)(y1 - y0);
            double length = Math.Sqrt((double)vx * vx + (double)vy * vy);
            float nx = length == 0 ? 1f : (float)(vx / length);
            float ny = length == 0 ? 0f : (float)(vy / length);
            float outset = (float)Math.PI / 8f;
            float ox = nx * outset, oy = ny * outset;
            int ax = (int)(((float)x0 - ox) * 64f);
            int ay = (int)(((float)y0 - oy) * 64f);
            int bx = (int)(((float)x1 + ox) * 64f);
            int by = (int)(((float)y1 + oy) * 64f);
            int alpha = Byte(color.A * opacity);
            if (lineWidth < 1.0) alpha = alpha * (int)(lineWidth * 256.0) >> 8;
            var paint = Premultiply(color, alpha);
            ScanHairline(pixels, width, height, ax, ay, bx, by, paint);
        }

        private static void ScanHairline(Color32[] pixels, int width, int height,
            int x0, int y0, int x1, int y1, Color32 paint)
        {
            if (Math.Abs(x1 - x0) > 511 * 64 || Math.Abs(y1 - y0) > 511 * 64)
            {
                int hx = (x0 >> 1) + (x1 >> 1), hy = (y0 >> 1) + (y1 >> 1);
                ScanHairline(pixels, width, height, x0, y0, hx, hy, paint);
                ScanHairline(pixels, width, height, hx, hy, x1, y1, paint);
                return;
            }
            bool horizontal = Math.Abs(x1 - x0) > Math.Abs(y1 - y0);
            if (!horizontal)
            {
                int swap = x0; x0 = y0; y0 = swap;
                swap = x1; x1 = y1; y1 = swap;
            }
            if (x0 > x1)
            {
                int swap = x0; x0 = x1; x1 = swap;
                swap = y0; y0 = y1; y1 = swap;
            }
            if (x0 == x1) return;
            int first = x0 >> 6, stop = (x1 + 63) >> 6;
            int slope = y0 == y1 ? 0 : ((y1 - y0) << 16) / (x1 - x0);
            int minor = (y0 << 10) + (y0 == y1 ? 0 :
                ((slope * (32 - (x0 & 63)) + 32) >> 6));
            for (int major = first; major < stop; major++, minor += slope)
            {
                int coverage = stop - first == 1 ? x1 - x0 :
                    major == first ? 64 - (x0 & 63) :
                    major == stop - 1 && (x1 & 63) != 0 ? x1 & 63 : 64;
                int shifted = minor + 32768;
                int lower = shifted >> 16;
                int a = (shifted >> 8) & 255;
                int upperAlpha = ((255 - a) * coverage) >> 6;
                int lowerAlpha = (a * coverage) >> 6;
                if (horizontal)
                {
                    BlendCoverage(pixels, width, height, major, lower - 1, paint, upperAlpha);
                    BlendCoverage(pixels, width, height, major, lower, paint, lowerAlpha);
                }
                else
                {
                    BlendCoverage(pixels, width, height, lower - 1, major, paint, upperAlpha);
                    BlendCoverage(pixels, width, height, lower, major, paint, lowerAlpha);
                }
            }
        }

        private static Color32 Premultiply(Ink color, int alpha)
        {
            return new Color32(
                (byte)((Byte(color.R) * alpha + 127) / 255),
                (byte)((Byte(color.G) * alpha + 127) / 255),
                (byte)((Byte(color.B) * alpha + 127) / 255), (byte)alpha);
        }

        // Scale premultiplied paint by coverage before byte source-over.
        private static void BlendCoverage(Color32[] pixels, int width, int height,
            int x, int y, Color32 paint, int coverage)
        {
            if (x < 0 || y < 0 || x >= width || y >= height || coverage == 0) return;
            int i = (height - 1 - y) * width + x;
            Color32 p = pixels[i];
            int scale = coverage + 1;
            int a = paint.a * scale >> 8;
            int retain = 256 - a;
            pixels[i] = new Color32(
                (byte)Math.Min(255, (paint.r * scale >> 8) + (p.r * retain >> 8)),
                (byte)Math.Min(255, (paint.g * scale >> 8) + (p.g * retain >> 8)),
                (byte)Math.Min(255, (paint.b * scale >> 8) + (p.b * retain >> 8)),
                (byte)Math.Min(255, a + (p.a * retain >> 8)));
        }
    }
}
