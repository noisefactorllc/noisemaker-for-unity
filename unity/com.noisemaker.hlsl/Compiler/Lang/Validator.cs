// Validator.cs — semantic analysis: AST -> flattened plans (reference/02).
//
// Ports the core of shaders/src/lang/validator.js. Implemented scope:
//   - MULTIPLE chain statements / plans in one program (each with its own .write(oN));
//     a global tempIndex spans all plans (reference/02 H1).
//   - read(oN) starter chains + mid-chain .write(oN) passthrough (_read/_write builtins).
//   - let-bindings: `let x = <expr>` substitution (numbers, enums, surface refs, partial
//     calls) via ProcessVars/Substitute/ResolveCall (reference/02 §2.8-§3).
//   - Multi-input effects (mixer): surface-typed args that are a surface ref (e.g.
//     blendMode(tex: o1)) or an inline chain/read() wiring a second input (§6.1). The
//     ENCLOSING statement's writeName is threaded into nested surface-arg subchains so
//     `prev` resolves to the parent write target (§5.3).
//   - Tier-1 effects, literal + enum + array + color/vec args, palette.
// Staged (NotImplementedException + TODO(scope)), FAIL LOUDLY (never silently wrong):
//   subchain, if/elif, loop-control (break/continue/return), Func, state-value args.
// Implemented: read3d/write3d/3D lane (graph-verified), agents/points, recursive
// oscillator/MIDI/audio automation, loopBegin/End.
//
// PARITY-CRITICAL behaviors replicated:
//  - GLOBAL monotonic tempIndex across all plans; exact `tempIndex++` ORDER defines
//    every temp/from integer (reference/02 H1). Effect step temp is allocated AFTER
//    arg resolution (which may recurse into processChain for inline surface subchains),
//    matching the reference (validator.js: idx = tempIndex++ after the spec.args loop).
//  - Op-name resolution is FIRST-MATCH over [explicit-resolved, ...searchOrder]
//    (reference/02 §5.2 H8).
//  - clamp uses double comparisons; S002 is a warning; out-of-range silently clamped
//    (reference/02 §2.1, H13).
//  - member resolution falls back to 0 (reference/02 §6.6 H14).
//  - args keyed by def.name (DSL name), NOT uniform (reference/02 H9).
//  - errors are collected, not thrown, except missing-search (reference/02 §1.2 H11).
//
// Pure C#, no UnityEngine.

using System;
using System.Collections.Generic;
using System.Text;
using Noisemaker.Hlsl.Compiler.Graph;

namespace Noisemaker.Hlsl.Compiler
{
    public sealed class Validator
    {
        private static readonly HashSet<string> StateSurfaces =
            new HashSet<string> { "time", "frame", "mouse", "resolution", "seed", "a" };
        private static readonly HashSet<string> StateValues = new HashSet<string>
        {
            "time","frame","mouse","resolution","seed","a","u1","u2","u3","u4",
            "s1","s2","b1","b2","a1","a2","deltaTime"
        };
        private static readonly HashSet<string> AllowedStringParams =
            new HashSet<string>
            {
                "text.text", "text.font", "text.justify", "text.style",
                "midi.name", "midi.id", "audio.name", "audio.id"
            };
        private static readonly HashSet<string> SurfacePassthroughCalls =
            new HashSet<string> { "read" };

        private readonly EffectRegistry _reg;
        private readonly List<Diagnostic> _diagnostics = new List<Diagnostic>();
        private readonly Dictionary<string, Node> _symbols = new Dictionary<string, Node>();
        private readonly HashSet<string> _reportedAutomationCycles = new HashSet<string>();
        private List<string> _searchOrder;
        private int _tempIndex;
        private const int MaxAutomationDepth = 8;

        private Validator(EffectRegistry reg) { _reg = reg; }

        public static ValidateResult Validate(ProgramNode ast, EffectRegistry reg)
        {
            return new Validator(reg).Run(ast);
        }

        private ValidateResult Run(ProgramNode ast)
        {
            string render = ast.Render != null ? ast.Render.Name : null;
            _searchOrder = ast.Namespace != null ? ast.Namespace.SearchOrder : null;
            if (_searchOrder == null || _searchOrder.Count == 0)
                throw new Exception("Missing required 'search' directive. Every program must start with 'search <namespace>, ...' to specify namespace search order.");

            ProcessVars(ast.Vars);

            var plans = new List<Plan>();
            if (ast.Plans != null)
                foreach (Node stmt in ast.Plans)
                {
                    Plan p = CompileStmt(stmt);
                    if (p != null) plans.Add(p);
                }

            return new ValidateResult
            {
                Plans = plans,
                Diagnostics = _diagnostics,
                Render = render,
                SearchNamespaces = new List<string>(_searchOrder)
            };
        }

        // --- diagnostics ----------------------------------------------------

        private void PushDiag(string code, Node node, string message = null)
        {
            if (message == null) message = DiagnosticTable.DefaultMessage(code);
            string identName = ExtractIdentifierName(node);
            string enriched = message;
            if (identName != null && !message.Contains(identName) && !message.Contains("'"))
                enriched = message + ": '" + identName + "'";
            var diag = new Diagnostic
            {
                Code = code,
                Message = enriched,
                Severity = DiagnosticTable.Severity(code),
                Identifier = identName
            };
            if (node != null && node.LocLine.HasValue)
            {
                diag.Line = node.LocLine;
                diag.Column = node.LocCol;
            }
            _diagnostics.Add(diag);
        }

        private static string ExtractIdentifierName(Node node)
        {
            if (node == null) return null;
            switch (node)
            {
                case IdentNode i: return i.Name;
                case MemberNode m: return string.Join(".", m.Path);
                case CallNode c: return c.Name;
                case FuncNode f when f.Src != null:
                    return "{" + f.Src.Substring(0, Math.Min(30, f.Src.Length)) + (f.Src.Length > 30 ? "..." : "") + "}";
            }
            return "[" + node.Kind + "]";
        }

        // --- vars / symbols (reference/02 §3) -------------------------------

        private void ProcessVars(List<VarAssignNode> vars)
        {
            if (vars == null) return;
            foreach (VarAssignNode v in vars)
            {
                Node expr = Substitute(Clone(v.Expr), new List<string> { v.Name });
                if (expr != null && IsStarterChain(expr))
                {
                    Node head = FirstChainCall(expr);
                    if (head != null) PushDiag("S006", head);
                }
                if (expr == null || (expr is IdentNode idn && (idn.Name == "null" || idn.Name == "undefined")))
                {
                    PushDiag("S004", v);
                    continue;
                }
                if (expr is IdentNode ie && !_symbols.ContainsKey(ie.Name) && !StateValues.Contains(ie.Name)
                    && _reg.GetOp(ie.Name) == null && !CanResolveOpName(ie.Name))
                {
                    PushDiag("S003", ie);
                    continue;
                }
                if (expr is ChainNode cn && cn.Chain.Count == 1)
                {
                    _symbols[v.Name] = cn.Chain[0];
                }
                else if (expr is MemberNode mn)
                {
                    double? resolved = ResolveEnumNumber(mn.Path);
                    if (resolved.HasValue) _symbols[v.Name] = new NumberNode { Value = resolved.Value };
                    else _symbols[v.Name] = expr;
                }
                else
                {
                    _symbols[v.Name] = expr;
                }
            }
        }

        // --- enum resolution (reference/02 §2.5) ----------------------------

        // Returns the numeric value of a path, or null if not a number. Precedence:
        // symbols > project enums > std enums (reference/02 §2.5 H3).
        private double? ResolveEnumNumber(IReadOnlyList<string> path)
        {
            if (path == null || path.Count == 0) return null;
            string head = path[0];
            // symbols
            if (_symbols.TryGetValue(head, out Node sym))
            {
                if (path.Count == 1)
                {
                    if (sym is NumberNode nn) return nn.Value;
                    if (sym is BooleanNode bn) return bn.Value ? 1 : 0;
                    return null;
                }
                return null; // symbol subtrees are not enum trees in this scope
            }
            EnumNode node;
            if (!Enums.TryGetHead(head, out node)) return null;
            for (int i = 1; i < path.Count; i++)
            {
                if (node == null || node.HasValue) return null;
                if (!node.Children.TryGet(path[i], out node)) return null;
            }
            return (node != null && node.HasValue) ? (double?)node.Value : null;
        }

        private bool CanResolveOpName(string name)
        {
            foreach (string ns in _searchOrder)
                if (_reg.GetOp(ns + "." + name) != null) return true;
            return false;
        }

        // --- clone / substitute (reference/02 §2.6 / §2.10) -----------------

        // JSON deep-clone analog (reference/02 §2.6). Only the node shapes that flow
        // through substitution in the first-cut scope are cloned structurally.
        private static Node Clone(Node node)
        {
            Node copy;
            switch (node)
            {
                case null: return null;
                case NumberNode n: copy = new NumberNode { Value = n.Value, VarRef = n.VarRef }; break;
                case StringNode s: copy = new StringNode { Value = s.Value }; break;
                case BooleanNode b: copy = new BooleanNode { Value = b.Value }; break;
                case ColorNode c: copy = new ColorNode { Value = (double[])c.Value.Clone() }; break;
                case IdentNode i: copy = new IdentNode { Name = i.Name, VarRef = i.VarRef }; break;
                case MemberNode m: copy = new MemberNode { Path = new List<string>(m.Path), VarRef = m.VarRef }; break;
                case OutputRefNode o: copy = new OutputRefNode { Name = o.Name }; break;
                case SurfaceRefNode sr: copy = new SurfaceRefNode(sr.Kind) { Name = sr.Name }; break;
                case ArrayLiteralNode a:
                {
                    var els = new List<Node>();
                    foreach (Node e in a.Elements) els.Add(Clone(e));
                    copy = new ArrayLiteralNode { Elements = els };
                    break;
                }
                case FuncNode f: copy = new FuncNode { Src = f.Src }; break;
                case ReadNode r: copy = new ReadNode { Surface = Clone(r.Surface), Skip = r.Skip }; break;
                case Read3DNode r3: copy = new Read3DNode { Tex3d = Clone(r3.Tex3d), Geo = Clone(r3.Geo), Skip = r3.Skip }; break;
                case CallNode call: copy = CloneCall(call); break;
                case ChainNode chain:
                {
                    var c = new ChainNode();
                    foreach (Node e in chain.Chain) c.Chain.Add(Clone(e));
                    copy = c;
                    break;
                }
                case OscillatorNode osc:
                    copy = new OscillatorNode
                    {
                        OscType = Clone(osc.OscType), Min = Clone(osc.Min), Max = Clone(osc.Max),
                        Speed = Clone(osc.Speed), Offset = Clone(osc.Offset), Seed = Clone(osc.Seed),
                        VarRef = osc.VarRef
                    };
                    break;
                case MidiNode mi:
                    copy = new MidiNode
                    {
                        Channel = Clone(mi.Channel), Mode = Clone(mi.Mode), Min = Clone(mi.Min),
                        Max = Clone(mi.Max), Sensitivity = Clone(mi.Sensitivity),
                        Name = Clone(mi.Name), Id = Clone(mi.Id),
                        VarRef = mi.VarRef
                    };
                    break;
                case AudioNode au:
                    copy = new AudioNode
                    {
                        Band = Clone(au.Band), Min = Clone(au.Min), Max = Clone(au.Max),
                        Channel = Clone(au.Channel), Name = Clone(au.Name), Id = Clone(au.Id),
                        VarRef = au.VarRef
                    };
                    break;
                default: copy = node; break;
            }
            copy.LocLine = node.LocLine;
            copy.LocCol = node.LocCol;
            return copy;
        }

        private static CallNode CloneCall(CallNode call)
        {
            var c = new CallNode { Name = call.Name, Namespace = call.Namespace };
            foreach (Node a in call.Args) c.Args.Add(Clone(a));
            if (call.Kwargs != null)
            {
                c.Kwargs = new OrderedKwargs();
                foreach (string k in call.Kwargs.Keys) c.Kwargs.Set(k, Clone(call.Kwargs.Get(k)));
            }
            return c;
        }

        // recursive variable inlining (reference/02 §2.10).
        private Node Substitute(Node node, List<string> resolving = null)
        {
            if (node == null) return null;
            if (resolving == null) resolving = new List<string>();
            if (node is IdentNode cycleIdent && resolving.Contains(cycleIdent.Name))
            {
                int cycleStart = resolving.IndexOf(cycleIdent.Name);
                var cycle = resolving.GetRange(cycleStart, resolving.Count - cycleStart);
                cycle.Add(cycleIdent.Name);
                string cycleKey = string.Join(" -> ", cycle);
                if (_reportedAutomationCycles.Add(cycleKey))
                    PushDiag("S001", cycleIdent, "Automation cycle detected: " + cycleKey);
                return new NumberNode
                {
                    Value = 0,
                    LocLine = cycleIdent.LocLine,
                    LocCol = cycleIdent.LocCol
                };
            }
            if (node is IdentNode id && _symbols.ContainsKey(id.Name))
            {
                var nested = new List<string>(resolving) { id.Name };
                Node result = Substitute(Clone(_symbols[id.Name]), nested);
                if (result != null) SetVarRef(result, id.Name);
                return result;
            }
            if (node is OscillatorNode osc)
            {
                osc.OscType = Substitute(osc.OscType, resolving);
                osc.Min = Substitute(osc.Min, resolving);
                osc.Max = Substitute(osc.Max, resolving);
                osc.Speed = Substitute(osc.Speed, resolving);
                osc.Offset = Substitute(osc.Offset, resolving);
                osc.Seed = Substitute(osc.Seed, resolving);
                return osc;
            }
            if (node is MidiNode midi)
            {
                midi.Channel = Substitute(midi.Channel, resolving);
                midi.Mode = Substitute(midi.Mode, resolving);
                midi.Min = Substitute(midi.Min, resolving);
                midi.Max = Substitute(midi.Max, resolving);
                midi.Sensitivity = Substitute(midi.Sensitivity, resolving);
                midi.Name = Substitute(midi.Name, resolving);
                midi.Id = Substitute(midi.Id, resolving);
                return midi;
            }
            if (node is AudioNode audio)
            {
                audio.Band = Substitute(audio.Band, resolving);
                audio.Min = Substitute(audio.Min, resolving);
                audio.Max = Substitute(audio.Max, resolving);
                audio.Channel = Substitute(audio.Channel, resolving);
                audio.Name = Substitute(audio.Name, resolving);
                audio.Id = Substitute(audio.Id, resolving);
                return audio;
            }
            if (node is ChainNode chain)
            {
                var c = new ChainNode();
                foreach (Node e in chain.Chain)
                {
                    if (e is CallNode call)
                    {
                        var mapped = new CallNode { Name = call.Name };
                        foreach (Node a in call.Args) mapped.Args.Add(Substitute(a, resolving));
                        if (call.Kwargs != null)
                        {
                            mapped.Kwargs = new OrderedKwargs();
                            foreach (string k in call.Kwargs.Keys) mapped.Kwargs.Set(k, Substitute(call.Kwargs.Get(k), resolving));
                        }
                        c.Chain.Add(ResolveCall(mapped));
                    }
                    else c.Chain.Add(e);
                }
                return c;
            }
            if (node is CallNode cn)
            {
                var mapped = new CallNode { Name = cn.Name, Namespace = cn.Namespace };
                foreach (Node a in cn.Args) mapped.Args.Add(Substitute(a, resolving));
                if (cn.Kwargs != null)
                {
                    mapped.Kwargs = new OrderedKwargs();
                    foreach (string k in cn.Kwargs.Keys) mapped.Kwargs.Set(k, Substitute(cn.Kwargs.Get(k), resolving));
                }
                return ResolveCall(mapped);
            }
            return node;
        }

        private static void SetVarRef(Node n, string name)
        {
            switch (n)
            {
                case NumberNode x: x.VarRef = name; break;
                case IdentNode x: x.VarRef = name; break;
                case MemberNode x: x.VarRef = name; break;
                case OscillatorNode x: x.VarRef = name; break;
                case MidiNode x: x.VarRef = name; break;
                case AudioNode x: x.VarRef = name; break;
            }
        }

        // variable substitution & partial application (reference/02 §2.8).
        private Node ResolveCall(CallNode call)
        {
            if (_symbols.TryGetValue(call.Name, out Node val))
            {
                if (val is IdentNode vi)
                    return new CallNode { Name = vi.Name, Args = call.Args, Kwargs = call.Kwargs, Namespace = call.Namespace };
                if (val is CallNode vc)
                {
                    var mergedArgs = new List<Node>(vc.Args ?? new List<Node>());
                    if (call.Args != null) mergedArgs.AddRange(call.Args); // APPEND (H5)
                    OrderedKwargs mergedKw = null;
                    if (vc.Kwargs != null)
                    {
                        mergedKw = new OrderedKwargs();
                        foreach (string k in vc.Kwargs.Keys) mergedKw.Set(k, vc.Kwargs.Get(k));
                    }
                    if (call.Kwargs != null)
                    {
                        if (mergedKw == null) mergedKw = new OrderedKwargs();
                        foreach (string k in call.Kwargs.Keys) mergedKw.Set(k, call.Kwargs.Get(k)); // call-site wins
                    }
                    var merged = new CallNode { Name = vc.Name, Args = mergedArgs, Kwargs = mergedKw };
                    merged.Namespace = call.Namespace ?? vc.Namespace;
                    return merged;
                }
            }
            return call;
        }

        // --- starter helpers (reference/02 §2.9) ----------------------------

        private static CallNode FirstChainCall(Node node)
        {
            if (node is CallNode c) return c;
            if (node is ChainNode ch && ch.Chain.Count > 0 && ch.Chain[0] is CallNode hc) return hc;
            return null;
        }

        private bool IsStarterChain(Node node)
        {
            if (!(node is ChainNode)) return false;
            (CallNode call, int index)? info = GetStarterInfo(node);
            return info.HasValue && info.Value.index == 0;
        }

        private (CallNode call, int index)? GetStarterInfo(Node node)
        {
            if (node is CallNode c)
            {
                string name = c.Name;
                if (c.Namespace != null && c.Namespace.Resolved != null) name = c.Namespace.Resolved + "." + c.Name;
                return _reg.IsStarterOp(name) ? ((CallNode, int)?)(c, 0) : null;
            }
            if (node is ChainNode ch)
            {
                for (int i = 0; i < ch.Chain.Count; i++)
                {
                    if (ch.Chain[i] is CallNode entry)
                    {
                        string name = entry.Name;
                        if (entry.Namespace != null && entry.Namespace.Resolved != null) name = entry.Namespace.Resolved + "." + entry.Name;
                        if (_reg.IsStarterOp(name)) return (entry, i);
                    }
                }
            }
            return null;
        }

        // --- statement compilation (reference/02 §4) ------------------------

        private Plan CompileStmt(Node stmt)
        {
            switch (stmt)
            {
                case IfStmtNode _:
                    // TODO(scope): if/elif/else -> Branch with evalCondition + compileBlock.
                    throw new NotImplementedException("if/elif/else branches are not implemented in the first-cut DSL frontend (reference/02 §4.1).");
                case BreakNode _:
                case ContinueNode _:
                case ReturnNode _:
                    // TODO(scope): loop control statements.
                    throw new NotImplementedException("break/continue/return are not implemented in the first-cut DSL frontend (reference/02 §4).");
                case ChainStatementNode cs:
                    return CompileChainStatement(cs);
                default:
                    return null;
            }
        }

        private Plan CompileChainStatement(ChainStatementNode stmt)
        {
            var chain = new List<Step>();
            var chainNode = new ChainNode { Chain = stmt.Chain };
            bool hasWrite = stmt.Write != null || stmt.Write3d != null;

            if (!hasWrite && IsStarterChain(chainNode))
                PushDiag("S006", stmt.Chain.Count > 0 ? stmt.Chain[0] : stmt);
            if (!hasWrite)
            {
                PushDiag("S001", stmt.Chain.Count > 0 ? stmt.Chain[0] : stmt, "Chain must have explicit write() or write3d() target");
                return null;
            }
            // write3dTarget (reference/02 §4.2; validator.js lines 439-442). When a chain
            // TERMINATES with write3d(vol, geo), the statement-level write3d target is recorded
            // for the plan. The terminal Write3DNode ALSO remains in stmt.Chain and is flattened
            // by ProcessChain into a chainable `_write3d` step (which emits the vol/geo blits);
            // plan.write stays null so the expander's final-chain blit (§4.11) is skipped.
            SurfaceRef write3dTex3d = null, write3dGeo = null;
            if (stmt.Write3d != null)
            {
                write3dTex3d = new SurfaceRef { Kind = "vol", Name = SurfaceName(stmt.Write3d.Tex3d) };
                write3dGeo = new SurfaceRef { Kind = "geo", Name = SurfaceName(stmt.Write3d.Geo) };
            }

            string writeName = (stmt.Write is OutputRefNode orf) ? orf.Name
                : (stmt.Write is SurfaceRefNode srf ? srf.Name : null);

            int? finalIndex = ProcessChain(chain, stmt.Chain, null, false, writeName);

            WriteTarget writeSurf = null;
            if (stmt.Write is OutputRefNode oo) writeSurf = new WriteTarget { Kind = "output", Name = oo.Name };
            else if (stmt.Write is SurfaceRefNode ss) writeSurf = new WriteTarget { Kind = "output", Name = ss.Name };

            return new Plan { Chain = chain, Write = writeSurf, Final = finalIndex, Write3dTex3d = write3dTex3d, Write3dGeo = write3dGeo };
        }

        // --- chain flattening (reference/02 §5) -----------------------------

        private int? ProcessChain(List<Step> chain, List<Node> calls, int? input,
                                  bool allowStarterless, string writeName)
        {
            int? current = input;
            foreach (Node original in calls)
            {
                // Built-in pipeline nodes (reference/02 §5.1).
                if (original is ReadNode rd)
                {
                    if (current != null)
                    {
                        PushDiag("S001", rd, "read() is a starter node and cannot be chained inline. Use standalone read() to start a new chain.");
                        continue;
                    }
                    SurfaceRef surface = ToSurface(rd.Surface);
                    if (surface == null) { PushDiag("S001", rd, "read() requires a valid surface reference"); continue; }
                    int rdIdx = _tempIndex++;
                    var rdArgs = new StepArgs();
                    rdArgs.Set("tex", ArgValue.OfSurface(surface));
                    if (rd.Skip) rdArgs.Set("_skip", ArgValue.Of(true));
                    var rdStep = new Step { Op = "_read", Args = rdArgs, From = null, Temp = rdIdx, Builtin = true, LeadingComments = original.LeadingComments };
                    chain.Add(rdStep);
                    current = rdIdx;
                    continue;
                }
                // read3d two-arg starter (reference/02 §5.1; validator.js lines 481-525).
                // Two-arg form `read3d(vol0, geo0)` is a STARTER node emitting a `_read3d`
                // builtin step with {tex3d,geo} surface args. Single-arg `read3d(vol0)` is a
                // param value (handled in ResolveVolumeArg), never reaches the chain here.
                if (original is Read3DNode r3 && r3.Geo != null)
                {
                    if (current != null)
                    {
                        PushDiag("S001", r3, "read3d() is a starter node and cannot be chained inline. Use standalone read3d() to start a new chain.");
                        continue;
                    }
                    SurfaceRef tex3d = Make3dRef(r3.Tex3d, "vol", NodeKind.VolRef);
                    SurfaceRef geo = Make3dRef(r3.Geo, "geo", NodeKind.GeoRef);
                    if (tex3d == null || geo == null)
                    {
                        PushDiag("S001", r3, "read3d() as starter requires tex3d and geo references");
                        continue;
                    }
                    int rd3Idx = _tempIndex++;
                    var rd3Args = new StepArgs();
                    rd3Args.Set("tex3d", ArgValue.OfSurface(tex3d));
                    rd3Args.Set("geo", ArgValue.OfSurface(geo));
                    if (r3.Skip) rd3Args.Set("_skip", ArgValue.Of(true));
                    var rd3Step = new Step { Op = "_read3d", Args = rd3Args, From = null, Temp = rd3Idx, Builtin = true, LeadingComments = original.LeadingComments };
                    chain.Add(rd3Step);
                    current = rd3Idx;
                    continue;
                }
                if (original is WriteNode wn)
                {
                    SurfaceRef surface = ToSurface(wn.Surface);
                    if (surface == null) { PushDiag("S001", wn, "write() requires a valid surface reference"); continue; }
                    if (current == null) { PushDiag("S005", wn, "write() requires an input - cannot be first in chain"); continue; }
                    int wrIdx = _tempIndex++;
                    var wrArgs = new StepArgs();
                    wrArgs.Set("tex", ArgValue.OfSurface(surface));
                    var wrStep = new Step { Op = "_write", Args = wrArgs, From = current, Temp = wrIdx, Builtin = true, LeadingComments = original.LeadingComments };
                    chain.Add(wrStep);
                    current = wrIdx;
                    continue;
                }
                // write3d chain node (reference/02 §5.1; validator.js lines 552-586). Emits a
                // chainable `_write3d` builtin step: blits the live 3D + geo lanes to the named
                // vol/geo surfaces while passing all lanes through.
                if (original is Write3DNode w3)
                {
                    SurfaceRef tex3d = Make3dRef(w3.Tex3d, "vol", NodeKind.VolRef);
                    SurfaceRef geo = Make3dRef(w3.Geo, "geo", NodeKind.GeoRef);
                    if (tex3d == null || geo == null)
                    {
                        PushDiag("S001", w3, "write3d() requires tex3d and geo references");
                        continue;
                    }
                    if (current == null)
                    {
                        PushDiag("S005", w3, "write3d() requires an input - cannot be first in chain");
                        continue;
                    }
                    int wr3Idx = _tempIndex++;
                    var wr3Args = new StepArgs();
                    wr3Args.Set("tex3d", ArgValue.OfSurface(tex3d));
                    wr3Args.Set("geo", ArgValue.OfSurface(geo));
                    var wr3Step = new Step { Op = "_write3d", Args = wr3Args, From = current, Temp = wr3Idx, Builtin = true, LeadingComments = original.LeadingComments };
                    chain.Add(wr3Step);
                    current = wr3Idx;
                    continue;
                }
                // Subchain / DSL LOOP bracket (reference/02 §5.1; validator.js
                // 'Subchain' branch lines 588-630). Emits _subchain_begin / _subchain_end
                // passthrough markers around the recursively-flattened body. tempIndex
                // parity: begin gets idx, body steps follow, end gets the next idx — the
                // SAME ordering as the reference (begin temp, recurse, end temp).
                if (original is SubchainNode sub)
                {
                    if (current == null)
                    {
                        PushDiag("S005", original, "subchain() requires an input - cannot be first in chain");
                        continue;
                    }
                    int iters = sub.Iterations ?? 1;

                    int beginIdx = _tempIndex++;
                    var beginArgs = new StepArgs();
                    if (sub.Name != null) beginArgs.Set("name", ArgValue.OfString(sub.Name));
                    if (sub.Id != null) beginArgs.Set("id", ArgValue.OfString(sub.Id));
                    // DSL LOOPS: iterations metadata lives ONLY on the begin marker; the
                    // expander reads it to tag the bracketed passes with a loop group.
                    if (iters > 1) beginArgs.Set("iterations", ArgValue.Of((double)iters));
                    var beginStep = new Step
                    {
                        Op = "_subchain_begin", Args = beginArgs, From = current,
                        Temp = beginIdx, Builtin = true, LeadingComments = original.LeadingComments
                    };
                    chain.Add(beginStep);
                    current = beginIdx;

                    // Recurse into the body, reusing all arg-resolution / validation logic.
                    current = ProcessChain(chain, sub.Body, current, false, writeName);

                    int endIdx = _tempIndex++;
                    var endArgs = new StepArgs();
                    if (sub.Name != null) endArgs.Set("name", ArgValue.OfString(sub.Name));
                    if (sub.Id != null) endArgs.Set("id", ArgValue.OfString(sub.Id));
                    if (iters > 1) endArgs.Set("iterations", ArgValue.Of((double)iters));
                    var endStep = new Step
                    {
                        Op = "_subchain_end", Args = endArgs, From = current,
                        Temp = endIdx, Builtin = true
                    };
                    chain.Add(endStep);
                    current = endIdx;
                    continue;
                }

                // Effect call (reference/02 §5.2).
                Node resolvedNode = ResolveCall((CallNode)Clone(original));
                CallNode call = (CallNode)resolvedNode;

                List<string> searchOrder = call.Namespace != null && call.Namespace.SearchOrder != null
                    ? call.Namespace.SearchOrder : _searchOrder;
                string opName = null;
                OpSpec spec = null;
                var candidates = new List<string>();
                if (call.Namespace != null && call.Namespace.Resolved != null)
                    candidates.Add(call.Namespace.Resolved + "." + call.Name);
                foreach (string ns in searchOrder) candidates.Add(ns + "." + call.Name);
                foreach (string cand in candidates)
                {
                    OpSpec s = _reg.GetOp(cand);
                    if (s != null) { opName = cand; spec = s; break; }
                }
                if (spec == null) { PushDiag("S001", original, "Unknown effect: '" + call.Name + "'"); continue; }

                string aliasWarning = _reg.CheckEffectAlias(opName);
                if (aliasWarning != null) PushDiag("S008", original, aliasWarning);

                if (opName == "prev")
                {
                    int idxp = _tempIndex++;
                    var argsp = new StepArgs();
                    argsp.Set("tex", ArgValue.OfSurface(new SurfaceRef { Kind = "output", Name = writeName }));
                    var stepp = new Step { Op = opName, Args = argsp, From = current, Temp = idxp, LeadingComments = original.LeadingComments };
                    chain.Add(stepp);
                    current = idxp;
                    continue;
                }

                bool isStarter = _reg.IsStarterOp(opName);
                bool starterlessRoot = current == null;
                bool allowPassthroughRoot = allowStarterless && SurfacePassthroughCalls.Contains(opName);
                if (starterlessRoot && !isStarter && !allowPassthroughRoot) { PushDiag("S005", original); continue; }
                bool starterHasInput = isStarter && current != null;
                int? fromInput = starterHasInput ? null : current;
                if (starterHasInput) PushDiag("S005", original);

                // Hook check (reference/02 §5.6) — staged. If a hook would be registered
                // for this bare name, we must port it; we currently have no hook registry,
                // so this is a no-op (no hooks in Tier-1). Agent effects are out of scope.

                var args = new StepArgs();
                // writeName is captured by the JS processChain closure, so nested
                // surface-arg subchains (mixer inputs) still see the ENCLOSING
                // statement's write target — critical for `prev` inside a mixer input
                // (reference/02 §5.3 / §6.1). Thread it through explicitly.
                ResolveArgs(chain, spec, call, opName, original, args, writeName);

                int idx = _tempIndex++;
                var step = new Step { Op = opName, Args = args, From = fromInput, Temp = idx, LeadingComments = original.LeadingComments };
                chain.Add(step);
                current = idx;
            }
            return current;
        }

        // --- argument resolution (reference/02 §6) --------------------------

        private void ResolveArgs(List<Step> chain, OpSpec spec, CallNode call, string opName, Node original, StepArgs args, string writeName)
        {
            OrderedKwargs kw = call.Kwargs;
            if (kw != null)
            {
                List<string> warnings = _reg.ResolveParamAliases(opName, kw);
                foreach (string w in warnings) PushDiag("S007", call, w);
            }
            var seen = new HashSet<string>();
            List<ParamDef> specArgs = spec.Args;

            for (int i = 0; i < specArgs.Count; i++)
            {
                ParamDef def = specArgs[i];
                Node node = (kw != null && kw.Has(def.Name)) ? kw.Get(def.Name)
                    : (i < call.Args.Count ? call.Args[i] : null);
                node = Substitute(node);
                string argKey = def.Name;

                // Color-splat special case (reference/02 §6 before per-type branch).
                if (kw == null && node is ColorNode cnode && def.Type != "color" && def.Name == "r"
                    && i + 2 < specArgs.Count && specArgs[i + 1].Name == "g" && specArgs[i + 2].Name == "b")
                {
                    args.Set("r", ArgValue.Of(cnode.Value[0]));
                    args.Set(specArgs[i + 1].Name, ArgValue.Of(cnode.Value[1]));
                    args.Set(specArgs[i + 2].Name, ArgValue.Of(cnode.Value[2]));
                    i += 2;
                    continue;
                }
                if (kw != null && kw.Has(def.Name)) seen.Add(def.Name);

                // ArrayLiteral (reference/02 §6 array-literal branch).
                if (node is ArrayLiteralNode al)
                {
                    var value = new List<double>();
                    foreach (Node el in al.Elements)
                    {
                        if (el is NumberNode en) value.Add(en.Value);
                        else { PushDiag("S002", el, "Array element must be a number for '" + def.Name + "' in " + call.Name + "()"); value.Add(0); }
                    }
                    args.Set(argKey, ArgValue.OfArray(value));
                    continue;
                }

                switch (def.Type)
                {
                    case "surface": ResolveSurfaceArg(chain, def, node, call, args, argKey, writeName); break;
                    case "color": ResolveColorArg(def, node, call, args, argKey); break;
                    case "vec3": ResolveVecArg(def, node, call, args, argKey, 3); break;
                    case "vec4": ResolveVecArg(def, node, call, args, argKey, 4); break;
                    case "boolean": ResolveBooleanArg(def, node, call, args, argKey); break;
                    case "member": ResolveMemberArg(def, node, call, args, argKey); break;
                    case "volume": ResolveVolumeArg(def, node, call, args, argKey, "vol", "vol"); break;
                    case "geometry": ResolveVolumeArg(def, node, call, args, argKey, "geo", "geo"); break;
                    case "string": ResolveStringArg(def, node, opName, original, call, args, argKey); break;
                    default: ResolveNumericArg(def, node, call, args, argKey); break;
                }
            }

            // _skip meta-arg (reference/02 §6.14).
            if (kw != null && kw.Has("_skip"))
            {
                Node skipNode = kw.Get("_skip");
                args.Set("_skip", ArgValue.Of(skipNode is BooleanNode sb && sb.Value));
                seen.Add("_skip");
            }
            // unknown-kwarg sweep (reference/02 §6.14).
            if (kw != null)
                foreach (string key in kw.Keys)
                    if (!seen.Contains(key))
                        PushDiag("S001", kw.Get(key), "Unknown argument '" + key + "' for " + call.Name + "()");
        }

        // 6.1 surface
        private void ResolveSurfaceArg(List<Step> chain, ParamDef def, Node node, CallNode call, StepArgs args, string argKey, string writeName)
        {
            if (node is StringNode)
            {
                PushDiag("S001", node, "String literal not allowed for surface parameter '" + def.Name + "'");
                SurfaceRef d = def.Default != null && def.Default.Kind == JsonKind.String
                    ? ToSurface(new IdentNode { Name = def.Default.AsString }) : null;
                args.Set(argKey, d != null ? ArgValue.OfSurface(d) : null);
                return;
            }
            SurfaceRef surf = null;
            bool invalidStarterChain = false;
            (CallNode call, int index)? starter = node != null ? GetStarterInfo(node) : null;

            if (node is ReadNode rn && rn.Surface != null) surf = ToSurface(rn.Surface);
            SurfaceRef inline = surf ?? CallToSurface(node);
            if (inline != null) surf = inline;
            else if (node is ChainNode chn)
            {
                int? idx = ProcessChain(chain, chn.Chain, null, true, writeName);
                if (idx.HasValue) surf = new SurfaceRef { Kind = "temp", Index = idx.Value, HasIndex = true };
            }
            else if (node is CallNode cnode)
            {
                int? idx = ProcessChain(chain, new List<Node> { cnode }, null, true, writeName);
                if (idx.HasValue) surf = new SurfaceRef { Kind = "temp", Index = idx.Value, HasIndex = true };
            }
            else if (starter.HasValue) { PushDiag("S005", starter.Value.call); invalidStarterChain = true; }
            else surf = ToSurface(node);

            if (surf == null)
            {
                if (invalidStarterChain) { args.Set(argKey, null); return; }
                bool hasDefault = def.Default != null && def.Default.Kind == JsonKind.String;
                if (!hasDefault)
                {
                    if (node == null) PushDiag("S001", call, "Missing required surface argument '" + def.Name + "' for " + call.Name + "()");
                    else if (node is IdentNode iv && !_symbols.ContainsKey(iv.Name)) PushDiag("S003", node, "Undefined variable '" + iv.Name + "' for '" + def.Name + "' in " + call.Name + "()");
                    else PushDiag("S001", node, "Invalid surface reference for '" + def.Name + "' in " + call.Name + "()");
                }
                else
                {
                    surf = ToSurface(new IdentNode { Name = def.Default.AsString })
                        ?? new SurfaceRef { Kind = "pipeline", Name = def.Default.AsString };
                }
            }
            args.Set(argKey, surf != null ? ArgValue.OfSurface(surf) : null);
        }

        // 6.2 color (hex strings kept as-is; literal default arrays preserved)
        private void ResolveColorArg(ParamDef def, Node node, CallNode call, StepArgs args, string argKey)
        {
            if (node is StringNode)
            {
                PushDiag("S001", node, "String literal not allowed for color parameter '" + def.Name + "'");
                args.Set(argKey, DefaultArg(def));
                return;
            }
            if (node is ColorNode cn)
            {
                args.Set(argKey, ArgValue.OfArray(new List<double>(cn.Value)));
                return;
            }
            if (node != null && !(node is IdentNode))
                PushDiag("S002", node, "Argument out of range for '" + def.Name + "' in " + call.Name + "()");
            args.Set(argKey, DefaultArg(def));
        }

        // 6.3 / 6.4 vec3 / vec4
        private void ResolveVecArg(ParamDef def, Node node, CallNode call, StepArgs args, string argKey, int n)
        {
            string vecName = n == 3 ? "vec3" : "vec4";
            if (node is StringNode)
            {
                PushDiag("S001", node, "String literal not allowed for " + vecName + " parameter '" + def.Name + "'");
                args.Set(argKey, DefaultArg(def, n == 3 ? new double[] { 0, 0, 0 } : new double[] { 0, 0, 0, 1 }));
                return;
            }
            if (node is CallNode vc && vc.Name == vecName && vc.Args.Count == n)
            {
                var value = new List<double>();
                foreach (Node a in vc.Args)
                {
                    if (a is NumberNode an) value.Add(an.Value);
                    else { PushDiag("S002", a, "Argument out of range for '" + def.Name + "' in " + call.Name + "()"); value.Add(0); }
                }
                args.Set(argKey, ArgValue.OfArray(value));
                return;
            }
            if (node is ColorNode cn)
            {
                var v = new List<double>();
                for (int k = 0; k < n; k++) v.Add(cn.Value[k]);
                args.Set(argKey, ArgValue.OfArray(v));
                return;
            }
            if (node != null && !(node is IdentNode))
                PushDiag("S002", node, "Argument out of range for '" + def.Name + "' in " + call.Name + "()");
            args.Set(argKey, DefaultArg(def, n == 3 ? new double[] { 0, 0, 0 } : new double[] { 0, 0, 0, 1 }));
        }

        // 6.5 boolean (literal forms; Func / state-value staged)
        private void ResolveBooleanArg(ParamDef def, Node node, CallNode call, StepArgs args, string argKey)
        {
            if (node is StringNode)
            {
                PushDiag("S001", node, "String literal not allowed for boolean parameter '" + def.Name + "'");
                args.Set(argKey, ArgValue.Of(DefaultBool(def)));
                return;
            }
            if (node is BooleanNode bn) { args.Set(argKey, ArgValue.Of(bn.Value)); return; }
            if (node is NumberNode nn) { args.Set(argKey, ArgValue.Of(nn.Value != 0)); return; }
            if (node is FuncNode)
                throw new NotImplementedException("Func boolean params ((state)=>...) are not implemented in the first-cut DSL frontend (reference/02 §6.5; cannot eval JS in C#).");
            if (node is IdentNode idn && StateValues.Contains(idn.Name))
                throw new NotImplementedException("state-value boolean params are not implemented in the first-cut DSL frontend (reference/02 §6.5).");
            if (node is IdentNode i2 && !StateValues.Contains(i2.Name)) PushDiag("S003", node);
            else if (node != null && !(node is IdentNode)) PushDiag("S002", node, "Argument out of range for '" + def.Name + "' in " + call.Name + "()");
            args.Set(argKey, ArgValue.Of(DefaultBool(def)));
        }

        // 6.6 member (enum-typed) -> NUMBER; falls back to 0 (H14)
        private void ResolveMemberArg(ParamDef def, Node node, CallNode call, StepArgs args, string argKey)
        {
            if (node is StringNode)
            {
                PushDiag("S001", node, "String literal not allowed for member/enum parameter '" + def.Name + "'");
                args.Set(argKey, DefaultArg(def));
                return;
            }
            List<string> prefix = EnumPaths.NormalizeMemberPath(def.EnumPath ?? def.Enum);
            List<string> path = null;
            if (node is MemberNode mn) path = EnumPaths.NormalizeMemberPath(mn.Path);
            else if (node is NumberNode nn) { args.Set(argKey, ArgValue.Of(nn.Value)); return; }
            else if (node is BooleanNode bn) { args.Set(argKey, ArgValue.Of(bn.Value ? 1 : 0)); return; }
            else if (node is IdentNode iv && StateValues.Contains(iv.Name))
                throw new NotImplementedException("state-value member params are not implemented in the first-cut DSL frontend (reference/02 §6.6).");
            else if (node is IdentNode id2) path = new List<string> { id2.Name };

            if (path == null) path = EnumPaths.NormalizeMemberPath(DefaultString(def));

            double? resolved = path != null ? ResolveEnumNumber(path) : null;
            if (!resolved.HasValue)
            {
                path = EnumPaths.ApplyEnumPrefix(path ?? new List<string>(), prefix);
                if (prefix != null && path != null && !EnumPaths.PathStartsWith(path, prefix))
                {
                    PushDiag("S001", node ?? call, "Invalid enum value for '" + def.Name + "': expected path starting with '" + string.Join(".", prefix) + "'");
                    path = new List<string>(prefix);
                }
                resolved = path != null ? ResolveEnumNumber(path) : null;
            }
            if (!resolved.HasValue)
            {
                List<string> fb = EnumPaths.NormalizeMemberPath(DefaultString(def));
                double? fbv = fb != null ? ResolveEnumNumber(fb) : null;
                resolved = fbv.HasValue ? fbv.Value : 0;
            }
            args.Set(argKey, ArgValue.Of(resolved.Value));
        }

        // 6.7 / 6.8 volume / geometry
        private void ResolveVolumeArg(ParamDef def, Node node, CallNode call, StepArgs args, string argKey, string kind, string pat)
        {
            if (node is StringNode)
            {
                PushDiag("S001", node, "String literal not allowed for " + kind + " parameter '" + def.Name + "'");
                args.Set(argKey, def.Default != null && def.Default.Kind == JsonKind.String
                    ? ArgValue.OfSurface(new SurfaceRef { Kind = kind, Name = def.Default.AsString }) : null);
                return;
            }
            SurfaceRef value = null;
            NodeKind refKind = kind == "vol" ? NodeKind.VolRef : NodeKind.GeoRef;
            if (node is Read3DNode r3 && r3.Tex3d != null && r3.Geo == null)
            {
                string nm = SurfaceName(r3.Tex3d);
                if (nm != null && MatchesPattern(nm, pat)) value = new SurfaceRef { Kind = kind, Name = nm };
                else { PushDiag("S001", node, "Invalid " + kind + " reference in read3d() for '" + def.Name + "'"); value = DefaultSurface(def, kind); }
            }
            else if (node is SurfaceRefNode sr && sr.Kind == refKind) value = new SurfaceRef { Kind = kind, Name = sr.Name };
            else if (node is IdentNode id)
            {
                if (id.Name == "none") value = new SurfaceRef { Kind = kind, Name = "none" };
                else if (MatchesPattern(id.Name, pat)) value = new SurfaceRef { Kind = kind, Name = id.Name };
                else { PushDiag("S001", node, "Invalid " + kind + " reference '" + id.Name + "' for '" + def.Name + "'"); value = DefaultSurface(def, kind); }
            }
            else if (node == null && def.Default != null && def.Default.Kind == JsonKind.String)
                value = new SurfaceRef { Kind = kind, Name = def.Default.AsString };
            args.Set(argKey, value != null ? ArgValue.OfSurface(value) : null);
        }

        // 6.9 string (STRICT allowlist)
        private void ResolveStringArg(ParamDef def, Node node, string opName, Node original, CallNode call, StepArgs args, string argKey)
        {
            string funcName = opName.Contains(".") ? opName.Substring(opName.LastIndexOf('.') + 1) : opName;
            string allowlistKey = funcName + "." + def.Name;
            if (!AllowedStringParams.Contains(allowlistKey))
            {
                PushDiag("S001", node ?? original, "String parameter '" + def.Name + "' on effect '" + funcName + "' is NOT in the allowed string params list. String params are strictly controlled - use enums or choices instead.");
                args.Set(argKey, DefaultArg(def));
                return;
            }
            if (node is StringNode sn) { args.Set(argKey, ArgValue.OfString(sn.Value)); return; }
            if (node is IdentNode idn && def.Choices != null)
            {
                if (def.Choices.TryGetValue(idn.Name, out double cv)) args.Set(argKey, ArgValue.Of(cv));
                else { PushDiag("S001", node, "Invalid choice '" + idn.Name + "' for string parameter '" + def.Name + "'"); args.Set(argKey, DefaultArg(def)); }
                return;
            }
            if (node != null) { PushDiag("S001", node, "String parameter '" + def.Name + "' requires a quoted string literal, got " + node.Kind); args.Set(argKey, DefaultArg(def)); return; }
            args.Set(argKey, DefaultArg(def));
        }

        // 6.10 numeric (float/int/unknown). Automation descriptors are compiled
        // recursively into graph data; Func and state-value args remain staged.
        private void ResolveNumericArg(ParamDef def, Node node, CallNode call, StepArgs args, string argKey)
        {
            if (node is StringNode)
            {
                PushDiag("S001", node, "String literal not allowed for numeric parameter '" + def.Name + "' - strings are only valid for type: \"string\" parameters");
                args.Set(argKey, DefaultArg(def));
                return;
            }
            if (node is NumberNode || node is BooleanNode)
            {
                double value = node is BooleanNode b ? (b.Value ? 1 : 0) : ((NumberNode)node).Value;
                double clamped = Clamp(value, def);
                if (clamped != value)
                    PushDiag("S002", node, "Argument out of range for '" + def.Name + "' in " + call.Name + "() (got " + value + ", clamped to " + clamped + ")");
                // _varRef wrapper (H16) preserved as a plain number in this first cut.
                args.Set(argKey, ArgValue.Of(clamped));
                return;
            }
            if (node is FuncNode)
                throw new NotImplementedException("Func numeric params ((state)=>...) are not implemented in the first-cut DSL frontend (reference/02 §6.10; cannot eval JS in C#).");
            if (node is OscillatorNode || node is MidiNode || node is AudioNode)
            {
                args.Set(argKey, ArgValue.OfWrapped(CompileAutomationDescriptor(node)));
                return;
            }
            if (node is MemberNode mn)
            {
                double? cur = ResolveEnumNumber(mn.Path);
                if (cur.HasValue)
                {
                    double v = Clamp(cur.Value, def);
                    if (v != cur.Value) PushDiag("S002", node, "Argument out of range for '" + def.Name + "' in " + call.Name + "() (got " + cur.Value + ", clamped to " + v + ")");
                    args.Set(argKey, ArgValue.Of(v));
                }
                else { PushDiag("S001", node, "Cannot resolve enum value for '" + def.Name + "': '" + string.Join(".", mn.Path) + "'"); args.Set(argKey, DefaultArg(def)); }
                return;
            }
            if (node is IdentNode idn && StateValues.Contains(idn.Name))
                throw new NotImplementedException("state-value numeric params (time/frame/...) are not implemented in the first-cut DSL frontend (reference/02 §6.10).");
            if (node is IdentNode ie && def.Enum != null)
            {
                List<string> prefix = EnumPaths.NormalizeMemberPath(def.Enum);
                List<string> path = prefix != null ? new List<string>(prefix) { ie.Name } : new List<string> { ie.Name };
                double? resolved = ResolveEnumNumber(path);
                if (resolved.HasValue) args.Set(argKey, ArgValue.Of(Clamp(resolved.Value, def)));
                else { PushDiag("S003", node); args.Set(argKey, DefaultArg(def)); }
                return;
            }
            if (node is IdentNode ic && def.Choices != null)
            {
                if (def.Choices.TryGetValue(ic.Name, out double cv)) args.Set(argKey, ArgValue.Of(Clamp(cv, def)));
                else { PushDiag("S003", node); args.Set(argKey, DefaultArg(def)); }
                return;
            }
            // else: defaultFrom or default
            if (node is IdentNode i2 && !StateValues.Contains(i2.Name)) PushDiag("S003", node);
            else if (node != null && !(node is IdentNode)) PushDiag("S002", node, "Argument out of range for '" + def.Name + "' in " + call.Name + "()");
            if (def.DefaultFrom != null && args.TryGet(def.DefaultFrom, out ArgValue refVal))
                args.Set(argKey, refVal);
            else
                args.Set(argKey, DefaultArg(def));
        }

        // 6.11-6.13 automation descriptors. Numeric descriptor fields may themselves
        // contain oscillator/MIDI/audio sources, up to eight nested field edges.
        private JsonValue CompileAutomationDescriptor(Node node, int depth = 0)
        {
            if (depth > MaxAutomationDepth)
            {
                PushDiag("S001", node,
                    "Automation nesting exceeds the maximum depth of " + MaxAutomationDepth);
                return JsonValue.Of(0.0);
            }

            if (node is OscillatorNode osc)
            {
                var map = new OrderedMap<string, JsonValue>();
                map.Add("type", JsonValue.Of("Oscillator"));
                map.Add("oscType", JsonValue.Of(ResolveAutomationEnum(
                    osc.OscType, "oscKind", 0, 0, 5, "osc", "type")));
                map.Add("min", ResolveAutomationNumber(
                    osc.Min, "osc", "min", 0, true, true, true, depth));
                map.Add("max", ResolveAutomationNumber(
                    osc.Max, "osc", "max", 1, true, true, true, depth));
                map.Add("speed", ResolveAutomationNumber(
                    osc.Speed, "osc", "speed", 1, true, true, false, depth));
                map.Add("offset", ResolveAutomationNumber(
                    osc.Offset, "osc", "offset", 0, true, true, false, depth));
                map.Add("seed", ResolveAutomationNumber(
                    osc.Seed, "osc", "seed", 1, true, true, false, depth));
                map.Add("_ast", NodeToJson(osc));
                if (!string.IsNullOrEmpty(osc.VarRef)) map.Add("_varRef", JsonValue.Of(osc.VarRef));
                return JsonValue.Of(map);
            }

            if (node is MidiNode midi)
            {
                var map = new OrderedMap<string, JsonValue>();
                map.Add("type", JsonValue.Of("Midi"));
                map.Add("channel", ResolveAutomationNumber(
                    midi.Channel, "midi", "channel", 1, true, false, false, depth));
                map.Add("mode", JsonValue.Of(ResolveAutomationEnum(
                    midi.Mode, "midiMode", 4, 0, 4, "midi", "mode")));
                map.Add("min", ResolveAutomationNumber(
                    midi.Min, "midi", "min", 0, true, true, true, depth));
                map.Add("max", ResolveAutomationNumber(
                    midi.Max, "midi", "max", 1, true, true, true, depth));
                map.Add("sensitivity", ResolveAutomationNumber(
                    midi.Sensitivity, "midi", "sensitivity", 1, true, true, false, depth));
                AddOptionalString(map, "name", ResolveAutomationString(midi.Name, "midi", "name"));
                AddOptionalString(map, "id", ResolveAutomationString(midi.Id, "midi", "id"));
                map.Add("_ast", NodeToJson(midi));
                if (!string.IsNullOrEmpty(midi.VarRef)) map.Add("_varRef", JsonValue.Of(midi.VarRef));
                return JsonValue.Of(map);
            }

            if (node is AudioNode audio)
            {
                double? band = ResolveAutomationEnumNullable(
                    audio.Band, "audioBand", 0, 4, "audio", "band");
                bool validMin = true;
                bool validMax = true;
                JsonValue min = ResolveAutomationNumber(
                    audio.Min, "audio", "min", 0, false, true, true, depth,
                    () => validMin = false, false);
                JsonValue max = ResolveAutomationNumber(
                    audio.Max, "audio", "max", 1, false, true, true, depth,
                    () => validMax = false, false);

                bool validChannel = true;
                double? channel = null;
                if (audio.Channel != null)
                {
                    if (audio.Channel is NumberNode channelNumber &&
                        channelNumber.Value == Math.Floor(channelNumber.Value) &&
                        channelNumber.Value >= 1)
                        channel = channelNumber.Value;
                    else
                    {
                        validChannel = false;
                        if (audio.Channel is StringNode)
                            PushDiag("S001", audio.Channel,
                                "String literal not allowed for audio() channel");
                        else
                            PushDiag("S002", audio.Channel,
                                "audio() channel must be a positive integer (got " +
                                AutomationNodeDisplay(audio.Channel) + ")");
                    }
                }

                string name = ResolveAutomationString(audio.Name, "audio", "name");
                string id = ResolveAutomationString(audio.Id, "audio", "id");
                bool validName = audio.Name == null || name != null;
                bool validId = audio.Id == null || id != null;

                var map = new OrderedMap<string, JsonValue>();
                map.Add("type", JsonValue.Of("Audio"));
                if (band.HasValue) map.Add("band", JsonValue.Of(band.Value));
                map.Add("min", min);
                map.Add("max", max);
                if (channel.HasValue) map.Add("channel", JsonValue.Of(channel.Value));
                AddOptionalString(map, "name", name);
                AddOptionalString(map, "id", id);
                map.Add("_invalid", JsonValue.Of(!band.HasValue || !validMin || !validMax ||
                    !validName || !validId || !validChannel));
                map.Add("_ast", NodeToJson(audio));
                if (!string.IsNullOrEmpty(audio.VarRef)) map.Add("_varRef", JsonValue.Of(audio.VarRef));
                return JsonValue.Of(map);
            }

            return JsonValue.Of(0.0);
        }

        private double ResolveAutomationEnum(Node node, string enumName, double fallback,
            int min, int max, string descriptorName, string fieldName)
        {
            double? resolved = ResolveAutomationEnumNullable(
                node, enumName, min, max, descriptorName, fieldName);
            return resolved ?? fallback;
        }

        private double? ResolveAutomationEnumNullable(Node node, string enumName,
            int min, int max, string descriptorName, string fieldName)
        {
            double? resolved = null;
            if (node is NumberNode number) resolved = number.Value;
            else if (node is MemberNode member) resolved = ResolveEnumNumber(member.Path);
            else if (node is IdentNode ident)
                resolved = ResolveEnumNumber(new List<string> { enumName, ident.Name });

            if (resolved.HasValue && resolved.Value >= min && resolved.Value <= max &&
                resolved.Value == Math.Floor(resolved.Value))
                return resolved.Value;

            if (node is StringNode)
                PushDiag("S001", node,
                    "String literal not allowed for " + descriptorName + "() " + fieldName);
            else
                PushDiag("S002", node,
                    descriptorName == "audio" && fieldName == "band"
                        ? "audio() band must resolve to an integer from 0 to 4 (got " +
                            (resolved.HasValue ? resolved.Value.ToString() : "") + ")"
                        : descriptorName + "() " + fieldName +
                            " must resolve to a supported enum value");
            return null;
        }

        private JsonValue ResolveAutomationNumber(Node node, string descriptorName,
            string fieldName, double fallback, bool allowBoolean, bool allowAutomation,
            bool clamp01, int depth, Action onInvalid = null, bool allowMember = true)
        {
            if (node == null) return JsonValue.Of(fallback);
            if (node is OscillatorNode || node is MidiNode || node is AudioNode)
            {
                if (allowAutomation)
                {
                    JsonValue compiled = CompileAutomationDescriptor(node, depth + 1);
                    JsonValue invalid = compiled.Get("_invalid");
                    if (invalid != null && invalid.Kind == JsonKind.Bool && invalid.AsBool)
                        onInvalid?.Invoke();
                    return compiled;
                }
                return RejectAutomationNumber(node, descriptorName, fieldName, fallback,
                    onInvalid, allowAutomation);
            }

            double? value = null;
            if (node is NumberNode number) value = number.Value;
            else if (allowBoolean && node is BooleanNode boolean) value = boolean.Value ? 1 : 0;
            else if (allowMember && node is MemberNode member) value = ResolveEnumNumber(member.Path);
            else
                return RejectAutomationNumber(node, descriptorName, fieldName, fallback,
                    onInvalid, allowAutomation);

            if (!value.HasValue || double.IsNaN(value.Value) || double.IsInfinity(value.Value))
            {
                onInvalid?.Invoke();
                PushDiag("S002", node, descriptorName + "() " + fieldName +
                    " must resolve to a finite number");
                return JsonValue.Of(fallback);
            }
            return JsonValue.Of(clamp01 ? Clamp01(value.Value) : value.Value);
        }

        private JsonValue RejectAutomationNumber(Node node, string descriptorName,
            string fieldName, double fallback, Action onInvalid, bool allowAutomation)
        {
            onInvalid?.Invoke();
            if (node is StringNode)
                PushDiag("S001", node,
                    "String literal not allowed for " + descriptorName + "() " + fieldName);
            else if (node is IdentNode ident)
                PushDiag("S003", node, "Undefined automation source '" + ident.Name +
                    "' for " + descriptorName + "() " + fieldName);
            else
                PushDiag("S002", node, descriptorName + "() " + fieldName +
                    " must be a number" + (allowAutomation ? " or automation source" : ""));
            return JsonValue.Of(fallback);
        }

        private string ResolveAutomationString(Node node, string descriptorName,
            string fieldName)
        {
            if (node == null) return null;
            string allowlistKey = descriptorName + "." + fieldName;
            if (!AllowedStringParams.Contains(allowlistKey))
            {
                PushDiag("S001", node, "String parameter '" + allowlistKey +
                    "' is not allowlisted");
                return null;
            }
            if (!(node is StringNode text))
            {
                PushDiag("S001", node, descriptorName + "() " + fieldName +
                    " requires a quoted string");
                return null;
            }
            if (text.Value.Length == 0)
            {
                PushDiag("S001", node, descriptorName + "() " + fieldName +
                    " must not be empty");
                return null;
            }
            return DecodeJsonStringLiteralContent(text.Value);
        }

        private static string DecodeJsonStringLiteralContent(string raw)
        {
            try
            {
                JsonValue parsed = JsonValue.Parse("\"" + raw + "\"");
                return parsed.AsString;
            }
            catch (FormatException)
            {
                var decoded = new StringBuilder();
                for (int i = 0; i < raw.Length; i++)
                {
                    if (raw[i] != '\\' || i + 1 >= raw.Length)
                    {
                        decoded.Append(raw[i]);
                        continue;
                    }
                    char next = raw[++i];
                    switch (next)
                    {
                        case '\'': decoded.Append('\''); break;
                        case '"': decoded.Append('"'); break;
                        case '\\': decoded.Append('\\'); break;
                        case 'n': decoded.Append('\n'); break;
                        case 'r': decoded.Append('\r'); break;
                        case 't': decoded.Append('\t'); break;
                        case 'b': decoded.Append('\b'); break;
                        case 'f': decoded.Append('\f'); break;
                        case 'v': decoded.Append('\v'); break;
                        case '0': decoded.Append('\0'); break;
                        default: decoded.Append('\\').Append(next); break;
                    }
                }
                return decoded.ToString();
            }
        }

        private static void AddOptionalString(OrderedMap<string, JsonValue> map,
            string key, string value)
        {
            if (value != null) map.Add(key, JsonValue.Of(value));
        }

        private static string AutomationNodeDisplay(Node node)
        {
            if (node is NumberNode number) return number.Value.ToString();
            if (node is IdentNode ident) return ident.Name;
            return node != null ? node.Kind.ToString() : "undefined";
        }

        private static JsonValue NodeToJson(Node node)
        {
            if (node == null) return JsonValue.Null;
            var map = new OrderedMap<string, JsonValue>();
            if (node is NumberNode number)
            {
                map.Add("type", JsonValue.Of("Number"));
                map.Add("value", JsonValue.Of(number.Value));
                AddNodeMetadata(map, node, number.VarRef);
            }
            else if (node is BooleanNode boolean)
            {
                map.Add("type", JsonValue.Of("Boolean"));
                map.Add("value", JsonValue.Of(boolean.Value));
                AddNodeMetadata(map, node, null);
            }
            else if (node is StringNode text)
            {
                map.Add("type", JsonValue.Of("String"));
                map.Add("value", JsonValue.Of(text.Value));
                AddNodeMetadata(map, node, null);
            }
            else if (node is IdentNode ident)
            {
                map.Add("type", JsonValue.Of("Ident"));
                map.Add("name", JsonValue.Of(ident.Name));
                AddNodeMetadata(map, node, ident.VarRef);
            }
            else if (node is MemberNode member)
            {
                map.Add("type", JsonValue.Of("Member"));
                var path = new List<JsonValue>();
                foreach (string item in member.Path) path.Add(JsonValue.Of(item));
                map.Add("path", JsonValue.Of(path));
                AddNodeMetadata(map, node, member.VarRef);
            }
            else if (node is OscillatorNode osc)
            {
                map.Add("type", JsonValue.Of("Oscillator"));
                map.Add("oscType", NodeToJson(osc.OscType));
                map.Add("min", NodeToJson(osc.Min));
                map.Add("max", NodeToJson(osc.Max));
                map.Add("speed", NodeToJson(osc.Speed));
                map.Add("offset", NodeToJson(osc.Offset));
                map.Add("seed", NodeToJson(osc.Seed));
                AddNodeMetadata(map, node, osc.VarRef);
            }
            else if (node is MidiNode midi)
            {
                map.Add("type", JsonValue.Of("Midi"));
                map.Add("channel", NodeToJson(midi.Channel));
                map.Add("mode", NodeToJson(midi.Mode));
                map.Add("min", NodeToJson(midi.Min));
                map.Add("max", NodeToJson(midi.Max));
                map.Add("sensitivity", NodeToJson(midi.Sensitivity));
                if (midi.Name != null) map.Add("name", NodeToJson(midi.Name));
                if (midi.Id != null) map.Add("id", NodeToJson(midi.Id));
                AddNodeMetadata(map, node, midi.VarRef);
            }
            else if (node is AudioNode audio)
            {
                map.Add("type", JsonValue.Of("Audio"));
                map.Add("band", NodeToJson(audio.Band));
                map.Add("min", NodeToJson(audio.Min));
                map.Add("max", NodeToJson(audio.Max));
                if (audio.Channel != null) map.Add("channel", NodeToJson(audio.Channel));
                if (audio.Name != null) map.Add("name", NodeToJson(audio.Name));
                if (audio.Id != null) map.Add("id", NodeToJson(audio.Id));
                AddNodeMetadata(map, node, audio.VarRef);
            }
            return JsonValue.Of(map);
        }

        private static void AddNodeMetadata(OrderedMap<string, JsonValue> map,
            Node node, string varRef)
        {
            if (node.LocLine.HasValue)
            {
                var loc = new OrderedMap<string, JsonValue>();
                loc.Add("line", JsonValue.Of(node.LocLine.Value));
                loc.Add("col", JsonValue.Of(node.LocCol ?? 0));
                map.Add("loc", JsonValue.Of(loc));
            }
            if (!string.IsNullOrEmpty(varRef)) map.Add("_varRef", JsonValue.Of(varRef));
        }

        private static double Clamp01(double x)
        {
            return Math.Max(0, Math.Min(1, x));
        }

        // --- helpers --------------------------------------------------------

        private static double Clamp(double value, ParamDef def)
        {
            if (def.HasMin && value < def.Min) return def.Min;
            if (def.HasMax && value > def.Max) return def.Max;
            return value;
        }

        // Convert a JSON default to an ArgValue (number/array/string/bool/null).
        private static ArgValue DefaultArg(ParamDef def, double[] fallbackArray = null)
        {
            JsonValue d = def.Default;
            if (d == null || d.Kind == JsonKind.Null)
                return fallbackArray != null ? ArgValue.OfArray(new List<double>(fallbackArray)) : null;
            switch (d.Kind)
            {
                case JsonKind.Number: return ArgValue.Of(d.AsNumber);
                case JsonKind.Bool: return ArgValue.Of(d.AsBool);
                case JsonKind.String: return ArgValue.OfString(d.AsString);
                case JsonKind.Array:
                {
                    var nums = new List<double>();
                    foreach (JsonValue e in d.AsArray) nums.Add(e.Kind == JsonKind.Number ? e.AsNumber : 0);
                    return ArgValue.OfArray(nums);
                }
                default: return null;
            }
        }

        private static bool DefaultBool(ParamDef def)
        {
            JsonValue d = def.Default;
            if (d == null) return false;
            if (d.Kind == JsonKind.Bool) return d.AsBool;
            if (d.Kind == JsonKind.Number) return d.AsNumber != 0;
            return false;
        }

        private static string DefaultString(ParamDef def)
        {
            JsonValue d = def.Default;
            return (d != null && d.Kind == JsonKind.String) ? d.AsString : null;
        }

        private static SurfaceRef DefaultSurface(ParamDef def, string kind)
        {
            return def.Default != null && def.Default.Kind == JsonKind.String
                ? new SurfaceRef { Kind = kind, Name = def.Default.AsString } : null;
        }

        // reference/02 §2.3 toSurface.
        private static SurfaceRef ToSurface(Node arg)
        {
            switch (arg)
            {
                case null: return null;
                case OutputRefNode o: return new SurfaceRef { Kind = "output", Name = o.Name };
                case SurfaceRefNode s when s.Kind == NodeKind.SourceRef: return new SurfaceRef { Kind = "source", Name = s.Name };
                case SurfaceRefNode s when s.Kind == NodeKind.XyzRef: return new SurfaceRef { Kind = "xyz", Name = s.Name };
                case SurfaceRefNode s when s.Kind == NodeKind.VelRef: return new SurfaceRef { Kind = "vel", Name = s.Name };
                case SurfaceRefNode s when s.Kind == NodeKind.RgbaRef: return new SurfaceRef { Kind = "rgba", Name = s.Name };
                case SurfaceRefNode s when s.Kind == NodeKind.MeshRef: return new SurfaceRef { Kind = "mesh", Name = s.Name };
                case IdentNode i when i.Name == "none": return new SurfaceRef { Kind = "output", Name = "none" };
                case IdentNode i when StateSurfaces.Contains(i.Name): return new SurfaceRef { Kind = "state", Name = i.Name };
                default: return null;
            }
        }

        // reference/02 §2.4 callToSurface.
        private static SurfaceRef CallToSurface(Node node)
        {
            if (node is ChainNode ch && ch.Chain.Count == 1) return CallToSurface(ch.Chain[0]);
            if (!(node is CallNode call) || !SurfacePassthroughCalls.Contains(call.Name)) return null;
            Node target = call.Args.Count > 0 ? call.Args[0] : null;
            if (target == null && call.Kwargs != null) target = call.Kwargs.Get("tex");
            return target != null ? ToSurface(target) : null;
        }

        private static string SurfaceName(Node n)
        {
            if (n is SurfaceRefNode sr) return sr.Name;
            if (n is OutputRefNode o) return o.Name;
            if (n is IdentNode i) return i.Name;
            return null;
        }

        // Build a {kind,name} surface ref for a read3d/write3d tex3d-or-geo operand
        // (reference/02 §5.1; validator.js: tex3d kind = VolRef?'vol':'tex3d', geo kind always
        // 'geo'). `refKind` is VolRef for the tex3d slot, GeoRef for the geo slot. Returns null
        // when the operand has no name (mirrors the `?.name ? {...} : null` guard).
        private static SurfaceRef Make3dRef(Node n, string defaultKind, NodeKind refKind)
        {
            string name = SurfaceName(n);
            if (name == null) return null;
            string kind = (defaultKind == "vol")
                ? (n is SurfaceRefNode sr && sr.Kind == refKind ? "vol" : "tex3d")
                : "geo";
            return new SurfaceRef { Kind = kind, Name = name };
        }

        // /^vol[0-7]$/ etc. as a literal check (the only patterns used are vol/geo).
        private static bool MatchesPattern(string name, string prefix)
        {
            if (name == null || name.Length != prefix.Length + 1) return false;
            if (!name.StartsWith(prefix, StringComparison.Ordinal)) return false;
            char d = name[prefix.Length];
            return d >= '0' && d <= '7';
        }
    }
}
