/*  SEATD - Semantics Aware Tools for D
 *  Copyright (c) 2007 Jascha Wetzel. All rights reserved
 *  License: Artistic License 2.0, see license.txt
 */
module util;

import tango.io.FilePath;
import tango.io.FileConst;
import tango.core.Memory;

import common;
import seatd.parser : SyntaxTree, GLRParser, WhitespaceGrammar, MainGrammar;
import seatd.symbol;

/**********************************************************************************************
    Parse a D source file.
    Params: input       = D source to parse
            filepath    = path of the file for identification
                        and modification time determination
**********************************************************************************************/
SyntaxTree parse(
    FilePath filepath, string input,
    bool detailed=false, bool recover=true, uint tab_width=4 )
{
    GLRParser   w = new WhitespaceGrammar,
                g = new MainGrammar(w, tab_width);
    return parse(g, filepath, input, detailed, recover);
}

/** ditto */
SyntaxTree parse(
    GLRParser parser, FilePath filepath, string input,
    bool detailed=false, bool recover=true )
{
    SyntaxTree root;

    if ( input is null )
        return null;
    if ( input[0 .. 4] == "Ddoc" )
        return null;

    // TODO: GC appears to free constant initializer data
    GC.disable;
    bool success = parser.parse(filepath.toString, input, root, detailed, recover);
    GC.enable;

    if ( !success )
        return null;

    return root;
}
