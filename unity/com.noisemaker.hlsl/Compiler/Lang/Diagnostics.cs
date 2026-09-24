// Diagnostics.cs — diagnostic codes + the collected-diagnostic record (reference/02 §7).
//
// The validator COLLECTS diagnostics (it does not throw, except missing-search,
// reference/02 §1.2 / H11). Codes + severities are the contract:
//   S001 error  Unknown identifier
//   S002 warning Argument out of range (clamp)
//   S003 error  Variable used before assignment
//   S004 error  Cannot assign null or undefined
//   S005 error  Illegal chain structure
//   S006 error  Starter chain missing write() call
//   S007 warning Deprecated parameter alias
//   S008 warning Deprecated effect
//
// Pure C#, no UnityEngine.

using System.Collections.Generic;

namespace Noisemaker.Hlsl.Compiler
{
    public enum DiagnosticSeverity { Error, Warning }

    public sealed class DiagnosticLocation
    {
        public int Line { get; set; }
        public int Column { get; set; }

        public override string ToString()
        {
            return $"({Line}:{Column})";
        }
    }

    public sealed class DiagnosticSpan
    {
        public int Start { get; set; }
        public int End { get; set; }

        public override string ToString()
        {
            return $"({Start}:{End})";
        }
    }

    public sealed class Diagnostic
    {
        public string Code { get; set; }
        public string Stage { get; set; }
        public string Message { get; set; }
        public DiagnosticSeverity Severity { get; set; }
        public string SeverityString => Severity == DiagnosticSeverity.Warning ? "warning" : "error";
        public int? Line { get; set; }       // from node.loc when available
        public int? Column { get; set; }
        public DiagnosticLocation Location { get; set; }
        public DiagnosticSpan Span { get; set; }
        public string Identifier { get; set; } // extractIdentifierName result, when present
    }

    public static class DiagnosticTable
    {
        private struct Entry
        {
            public string DefaultMessage;
            public DiagnosticSeverity Severity;
            public string Stage;

            public Entry(string defaultMessage, DiagnosticSeverity severity, string stage)
            {
                DefaultMessage = defaultMessage;
                Severity = severity;
                Stage = stage;
            }
        }

        // code -> (default message, severity, stage). Reference/02 §7 / upstream diagnostics.js.
        private static readonly Dictionary<string, Entry> _table =
            new Dictionary<string, Entry>
            {
                { "L001", new Entry("Unexpected character", DiagnosticSeverity.Error, "lexer") },
                { "L002", new Entry("Unterminated string literal", DiagnosticSeverity.Error, "lexer") },
                { "L003", new Entry("Unterminated comment", DiagnosticSeverity.Error, "lexer") },
                { "L004", new Entry("Output surface reference out of range", DiagnosticSeverity.Error, "lexer") },
                { "P001", new Entry("Unexpected token", DiagnosticSeverity.Error, "parser") },
                { "P002", new Entry("Expected closing parenthesis", DiagnosticSeverity.Error, "parser") },
                { "P003", new Entry("Invalid automation arguments", DiagnosticSeverity.Error, "parser") },
                { "P004", new Entry("Invalid search directive", DiagnosticSeverity.Error, "parser") },
                { "P005", new Entry("Invalid output operation", DiagnosticSeverity.Error, "parser") },
                { "P006", new Entry("Invalid subchain", DiagnosticSeverity.Error, "parser") },
                { "S001", new Entry("Unknown identifier", DiagnosticSeverity.Error, "semantic") },
                { "S002", new Entry("Argument out of range", DiagnosticSeverity.Warning, "semantic") },
                { "S003", new Entry("Variable used before assignment", DiagnosticSeverity.Error, "semantic") },
                { "S004", new Entry("Cannot assign null or undefined", DiagnosticSeverity.Error, "semantic") },
                { "S005", new Entry("Illegal chain structure", DiagnosticSeverity.Error, "semantic") },
                { "S006", new Entry("Starter chain missing write() call", DiagnosticSeverity.Error, "semantic") },
                { "S007", new Entry("Deprecated parameter alias", DiagnosticSeverity.Warning, "semantic") },
                { "S008", new Entry("Deprecated effect", DiagnosticSeverity.Warning, "semantic") },
                { "R001", new Entry("Runtime error", DiagnosticSeverity.Error, "runtime") },
            };

        public static string DefaultMessage(string code) { return _table[code].DefaultMessage; }
        public static DiagnosticSeverity Severity(string code) { return _table[code].Severity; }
        public static string Stage(string code) { return _table[code].Stage; }
    }
}
