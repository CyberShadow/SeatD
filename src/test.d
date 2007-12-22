/*  SEATD - Semantics Aware Tools for D
 *  Copyright (c) 2007 Jascha Wetzel. All rights reserved
 *  License: Artistic License 2.0, see license.txt
 */
module test;

import tango.text.convert.Layout;
import tango.io.Stdout;
import tango.io.File;
import tango.io.FilePath;
import tango.io.FileSystem;
import tango.io.FileScan;
import tango.util.time.StopWatch;
import tango.core.Memory;

alias char[] string;

import seatd.parser;
import seatd.module_data;

import win32.winbase;

/**************************************************************************************************

**************************************************************************************************/
string getFullPath(string filename)
{
	char[]	fullpath;
	char*	filepart;
	fullpath.length = 4096;
	int len = GetFullPathName(
		(filename~\0).ptr,
		fullpath.length,
		fullpath.ptr,
		&filepart
	);
	if ( len <= 0 )
		return null;
	fullpath.length = len;

	char[]	longfullpath;
	longfullpath.length = 4096;
	len = GetLongPathName(
        (fullpath~\0).ptr,
        longfullpath.ptr,
        longfullpath.length
	);
	longfullpath.length = len;
	return longfullpath;
}

/**************************************************************************************************

**************************************************************************************************/
ModuleData parseModule(GLRParser parser, string filename)
{
    SyntaxTree* root;
    ModuleData modinfo;

    auto input = cast(string)(new File(filename)).read;
    if ( input is null )
        return null;
    if ( input[0 .. 4] == "Ddoc" )
        return null;

/+     PerfTimer pt;
    pt.start;
 +/
    try
    {
        bool success = parser.parse(filename, input, &root, true);

//        pt.stop;
//        writefln("OK %s seconds, %s MTicks", pt.seconds, pt.mticks);

        if ( !success )
            return null;

//        root.print;
        modinfo = new ModuleData(filename, filename, 0);
        bool has_mod_decl;
        root.Module(modinfo, has_mod_decl);
    }
    catch ( Exception e )
    {
        Stdout(e.toUtf8).newline;
    }

    return modinfo;
}

void printMod(ModuleData mod)
{
    Stdout.format("Module name: \n", mod.fqname);
    foreach ( imp; mod.imports )
        Stdout.format("Import: {}\n", imp.module_name);
    foreach ( Declaration decl; mod.decls )
    {
        Stdout.format("Declaration: {} {} ({}:{})", Declaration.TYPE_NAMES[decl.dtType], decl.ident, decl.line, decl.column);
        for ( Declaration p = decl.parent; p !is null; p = p.parent )
            Stdout.format(" {}", p.ident);
        Stdout.newline;
    }
}

void main(string[] args)
{
    if ( args.length < 2 || !(new FilePath(args[1])).exists )
        throw new Exception("Usage: d <d files>");

    string cwd = FileSystem.getDirectory~"/";

    Stack!(string) files;
    foreach ( a; args[1..$] )
    {
        if ( a.length > 2 && a[1] != ':' && a[0] != '/' && a[0] != '\\' )
            files ~= getFullPath(cwd ~ a);
        else
            files ~= a;
    }

//    GC.disable;
    GLRParser   w = new WhitespaceGrammar,
                g = new MainGrammar(w);

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
            files ~= f.toUtf8;
        scan.sweep(filename, ".di");
        foreach ( f; scan.files )
            files ~= f.toUtf8;
    }
    while ( !files.empty )
    {
        filename = files.pop;

        ModuleData mod;
//        try
        {
            Stdout.formatln("parsing {}...", filename);
            mod = parseModule(g, filename);
        }
  /+       catch ( Exception e )
        {
            //e.print;
        }    
 +/
        if ( mod is null )
            failed ~= filename;
        else {
            ++success_count;
//            printMod(mod);
        }
    }

    auto seconds = sw.stop;

    Stdout.format("\n{} files parsed successfully\n{} files with errors{}\n", success_count, failed.length, failed.length>0?":":"");

    foreach ( f; failed )
        Stdout.format("{}\n", f);
    Stdout.formatln("\ntotal: {} seconds", seconds);//, pt.mticks);

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
