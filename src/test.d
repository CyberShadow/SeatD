/*  SEATD - Semantics Aware Tools for D
 *  Copyright (c) 2007-2008 Jascha Wetzel. All rights reserved
 *  License: Artistic License 2.0, see license.txt
 */
module test;

import tango.text.convert.Layout;
import tango.io.Stdout;
import tango.io.File;
import tango.io.FilePath;
import tango.io.FileSystem;
import tango.io.FileScan;
import tango.time.StopWatch;
import tango.core.Memory;

import seatd.parser : SyntaxTree, GLRParser, WhitespaceGrammar, MainGrammar;
import seatd.symbol;
import seatd.type;
import seatd.include_path;
import container;
import common;
import util;

void printSymbolTree(Symbol s, string indent="")
{
    auto decl = cast(Declaration)s;
    Stdout.formatln("{} {}", indent, s.toString);
    auto ss = cast(ScopeSymbol)s;
    if ( ss !is null )
    {
        foreach ( m; ss )
            printSymbolTree(m, indent~"  ");
    }
}

void main(string[] args)
{
    string[]  include_paths;
    while ( args.length > 1 )
    {
        if ( args[1][0 .. 2] == "-I" )
            include_paths ~= args[1][2 .. $];
        else
            break;
        args = args[0..1]~args[2..$];
    }

    if ( args.length < 2 || !(new FilePath(args[1])).exists )
        throw new Exception("Usage: d <d files>");

    string cwd = FileSystem.getDirectory~"/";

    Stack!(string) files;
    foreach ( a; args[1..$] )
    {
        if ( a.length > 2 && a[1] != ':' && a[0] != '/' && a[0] != '\\' )
            files ~= cwd ~ a;
        else
            files ~= a;
    }

    GLRParser   w = new WhitespaceGrammar,
                g = new MainGrammar(w, 4);

    StopWatch sw;
    sw.start;

    string[]    failed;
    uint        success_count;
    string      filename;
    filename = files.top;
    if ( (new FilePath(filename)).isFolder )
    {
        files.pop;
        auto scan = new FileScan;
        scan.sweep(filename, ".d");
        foreach ( f; scan.files )
            files ~= f.toString;
        scan.sweep(filename, ".di");
        foreach ( f; scan.files )
            files ~= f.toString;
    }

    auto root_package = new Package(null);

    while ( !files.empty )
    {
        filename = files.pop;

//        try
        {
            Stdout.formatln("parsing {}...", filename);
            auto fp = new FilePath(filename);
            SyntaxTree st = parse(g, fp, cast(string)(new File(fp)).read, true, false);
            auto mod = new Module(fp);
            st.seatdModule(root_package, mod);
            auto ip = new IncludePath;
            ip ~= include_paths;
            ip.extract(fp, mod.fqn);
            ip.parseImports(root_package, mod, true, true, false);

            Stdout("resolving types...").newline;
            resolve(root_package);
            Stdout("build location tree...").newline;
            auto loc_tree = root_package.buildLocationTree;

            // example auto-completion
            auto sym = loc_tree.find(Location(mod, 138, 47));
            while ( cast(ScopeSymbol)sym is null )
                sym = sym.parent_;
            Stdout.formatln("found {}", sym.toString);
            auto sc = cast(ScopeSymbol)sym;
            sym = sc.lookup("root_package_");
            if ( sym is null )
                Stdout.formatln("found null symbol");
            else
            {
                Stdout.formatln("found {} which is a {}", sym.toString, sym.classinfo.name);
                auto decl = cast(Declaration)sym;
                if ( decl !is null )
                {
                    assert(decl.type_ !is null);
                    Stdout.formatln("found a decl with a {} {}", decl.type_.classinfo.name, decl.type_.toString);
                    auto tsd = cast(TypeScopeDecl)decl.type_;
                    if ( tsd !is null )
                        sc = tsd.scopeDecl;
                }
                else
                    sc = cast(ScopeSymbol)sym;
                if ( sc is null )
                    Stdout.formatln("is not a ScopeSymbol/Decl");
                else
                {
                    auto cd = cast(ClassDeclaration)sc;
                    if ( cd !is null )
                    {
                        for ( auto i = cd; i !is null; i = i.base_class_decl_ )
                        {
                            foreach ( m; i )
                                Stdout.formatln("class member: {}", m.toString);
                        }
                    }
                    else foreach ( m; sc )
                        Stdout.formatln("non-class member: {}", m.toString);
                }
            }

        }
/+        catch ( Exception e )
        {
            //e.print;
        }
        if ( mod is null )
            failed ~= filename;
        else {
            ++success_count;
            printMod(mod);
        }
+/
//        printSymbolTree(root_package);
    }

    auto seconds = sw.stop;

    Stdout.format("\n{} files parsed successfully\n{} files with errors{}\n", success_count, failed.length, failed.length>0?":":"");

    foreach ( f; failed )
        Stdout.format("{}\n", f);
    Stdout.formatln("\ntotal: {} seconds", seconds);

    version(ProfileConflicts)
    {
        Stdout.format("\nmax branch stack length: {}\n", g.branch_stack_max);

        class SortedPair
        {
            uint count, state;

            this(uint c, uint s) {
                count = c;
                state = s;
            }

            int opCmp(Object o)
            {
                SortedPair p = cast(SortedPair)o;
                assert(p !is null);
                if ( count > p.count )
                    return -1;
                if ( count < p.count )
                    return 1;
                return 0;
            }
        }
        SortedPair[] asdf = new SortedPair[g.rr_conflict_counts.length];
        foreach ( i, state; g.rr_conflict_counts.keys )
            asdf[i] = new SortedPair(g.rr_conflict_counts[state], state);
        asdf.sort;
        foreach ( sp; asdf.sort )
            Stdout.format("State {} rr conflict hit {} times\n", sp.state, sp.count);

        asdf = new SortedPair[g.sr_conflict_counts.length];
        foreach ( i, state; g.sr_conflict_counts.keys )
            asdf[i] = new SortedPair(g.sr_conflict_counts[state], state);
        asdf.sort;
        foreach ( sp; asdf.sort )
            Stdout.format("State {} sr conflict hit {} times\n", sp.state, sp.count);

        asdf = new SortedPair[g.shift_failed_counts.length];
        foreach ( i, state; g.shift_failed_counts.keys )
            asdf[i] = new SortedPair(g.shift_failed_counts[state], state);
        asdf.sort;
        foreach ( sp; asdf.sort )
            Stdout.format("Shift in state {} failed {} times\n", sp.state, sp.count);

        asdf = new SortedPair[g.reduce_failed_counts.length];
        foreach ( i, state; g.reduce_failed_counts.keys )
            asdf[i] = new SortedPair(g.reduce_failed_counts[state], state);
        asdf.sort;
        foreach ( sp; asdf.sort )
            Stdout.format("Reduce in state {} failed {} times\n", sp.state, sp.count);
    }
}
