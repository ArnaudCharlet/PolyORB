--  idlac: IDL to Ada compiler.
--  Copyright (C) 1999 Tristan Gingold.
--
--  emails: gingold@enst.fr
--          adabroker@adabroker.eu.org
--
--  IDLAC is free software;  you can  redistribute it and/or modify it under
--  terms of the  GNU General Public License as published  by the Free Software
--  Foundation;  either version 2,  or (at your option) any later version.
--  IDLAC is distributed in the hope that it will be useful, but WITHOUT ANY
--  WARRANTY;  without even the  implied warranty of MERCHANTABILITY
--  or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
--  for  more details.  You should have  received  a copy of the GNU General
--  Public License  distributed with IDLAC;  see file COPYING.  If not, write
--  to  the Free Software Foundation,  59 Temple Place - Suite 330,  Boston,
--  MA 02111-1307, USA.
--

with Types; use Types;

package Tokens is

   --  All the idl_keywords
   --  CORBA 2.3 - 3.2.4
   --  must be synchronized with the token declarations
   All_Idl_Keywords : array (1 .. 47) of String_Cacc :=
     (new String'("abstract"),
      new String'("any"),
      new String'("attribute"),
      new String'("boolean"),
      new String'("case"),
      new String'("char"),
      new String'("const"),
      new String'("context"),
      new String'("custom"),
      new String'("default"),
      new String'("double"),
      new String'("enum"),
      new String'("exception"),
      new String'("factory"),
      new String'("FALSE"),
      new String'("fixed"),
      new String'("float"),
      new String'("in"),
      new String'("inout"),
      new String'("interface"),
      new String'("long"),
      new String'("module"),
      new String'("native"),
      new String'("Object"),
      new String'("octet"),
      new String'("oneway"),
      new String'("out"),
      new String'("private"),
      new String'("public"),
      new String'("raises"),
      new String'("readonly"),
      new String'("sequence"),
      new String'("short"),
      new String'("string"),
      new String'("struct"),
      new String'("supports"),
      new String'("switch"),
      new String'("TRUE"),
      new String'("truncatable"),
      new String'("typedef"),
      new String'("unsigned"),
      new String'("union"),
      new String'("ValueBase"),
      new String'("valuetype"),
      new String'("void"),
      new String'("wchar"),
      new String'("wstring")
      );

   --  the three kinds of identifiers : keywords, true
   --  identifiers or miscased keywords.
   type Idl_Keyword_State is
     (Is_Keyword, Is_Identifier, Bad_Case);

   --  All the possible tokens.
   type Idl_Token is
      (
   --  Position 0.
       T_Error,

   --  Keywords.
   --  Must start at position 1.
   --  Must be synchronised with tokens.adb
       T_Abstract,
       T_Any,
       T_Attribute,
       T_Boolean,
       T_Case,
       T_Char,
       T_Const,
       T_Context,
       T_Custom,
       T_Default,
       T_Double,
       T_Enum,
       T_Exception,
       T_Factory,
       T_False,
       T_Fixed,
       T_Float,
       T_In,
       T_Inout,
       T_Interface,
       T_Long,
       T_Module,
       T_Native,
       T_Object,
       T_Octet,
       T_Oneway,
       T_Out,
       T_Private,
       T_Public,
       T_Raises,
       T_Readonly,
       T_Sequence,
       T_Short,
       T_String,
       T_Struct,
       T_Supports,
       T_Switch,
       T_True,
       T_Truncatable,
       T_Typedef,
       T_Unsigned,
       T_Union,
       T_ValueBase,
       T_Valuetype,
       T_Void,
       T_Wchar,
       T_Wstring,
   --  Punctuation characters
       T_Sharp,                 -- #
       T_Semi_Colon,            -- ;
       T_Left_Cbracket,         -- {
       T_Right_Cbracket,        -- }
       T_Colon,                 -- :
       T_Comma,                 -- ,
       T_Equal,                 -- =
       T_Plus,                  -- +
       T_Minus,                 -- -
       T_Left_Paren,            -- (
       T_Right_Paren,           -- )
       T_Less,                  -- <
       T_Greater,               -- >
       T_Left_Sbracket,         -- [
       T_Right_Sbracket,        -- ]
       T_Apostrophe,            -- '
       T_Quote,                 -- "
       T_Backslash,             -- \
       T_Bar,                   -- |
       T_Circumflex,            -- ^
       T_Ampersand,             -- &
       T_Star,                  -- *
       T_Slash,                 -- /
       T_Percent,               -- %
       T_Tilde,                 -- ~
       T_Colon_Colon,           -- ::
       T_Greater_Greater,       -- >>
       T_Less_Less,             -- <<
   --  Literals
       T_Lit_Decimal_Integer,
       T_Lit_Octal_Integer,
       T_Lit_Hexa_Integer,
       T_Lit_Simple_Char,
       T_Lit_Escape_Char,
       T_Lit_Octal_Char,
       T_Lit_Hexa_Char,
       T_Lit_Unicode_Char,
       T_Lit_Wide_Simple_Char,
       T_Lit_Wide_Escape_Char,
       T_Lit_Wide_Octal_Char,
       T_Lit_Wide_Hexa_Char,
       T_Lit_Wide_Unicode_Char,
       T_Lit_Simple_Floating_Point,
       T_Lit_Exponent_Floating_Point,
       T_Lit_Pure_Exponent_Floating_Point,
       T_Lit_String,
       T_Lit_Simple_Fixed_Point,
       T_Lit_Floating_Fixed_Point,
   --  Identifier
       T_Identifier,
   --  Misc
       T_Eof
       );


   --  definition of the alphabetic characters in idl
   --  CORBA V2.3 table 3-2, 3-3
   function Is_Alphabetic_Character (C : Standard.Character) return Boolean;
   function Is_Digit_Character (C : Standard.Character) return Boolean;
   function Is_Octal_Digit_Character (C : Standard.Character) return Boolean;
   function Is_Hexa_Digit_Character (C : Standard.Character) return Boolean;
   function Is_Identifier_Character (C : Standard.Character) return Boolean;
   --  Identifier characters ar either alphabetic characters
   --  or digits or '_'



   --  Advance the lexical analyse until a new token is found.
   --  An invalid token will make function TOKEN returns t_error.
   procedure Next_Token;

   --  Get the current token.
   function Token return Idl_Token;

   --  Return the location of the current token.
   function Get_Loc return Location;

   --  If the current token is an identifier (t_identifier), then return
   --  its value as a string.
   function Get_Identifier return String;

   --  FIXME:  if the current token is a literal, returns its value as a
   --  string.
   function Get_Literal return String;

   --  Make function TOKEN returns TOK at it next call, without performing
   --  any other action.
   --  The purpose is to handle some errors, such as '>>' instead of '> >'.
   --  TOK cannot be t_error.
   --  This procedure can stack only one token, ie, it must be called after
   --  next_token.
   procedure Set_Replacement_Token (Tok : Idl_Token);

   --  checks whether s is an Idl keyword or not
   --  the result can be Is_Keyword if it is,
   --  Is_Identifier if it is not and Bad_Case if
   --  it is one but with bad case
   --  CORBA V2.3, 3.2.4 :
   --  keywords must be written exactly as in the above list. Identifiers
   --  that collide with keywords (...) are illegal.
   procedure Is_Idl_Keyword (S : in String;
                             Is_A_Keyword : out Idl_Keyword_State;
                             Tok : out Idl_Token);


   subtype Idl_Keywords is Idl_Token range T_Any .. T_Wstring;

   function Idl_Compare (Left, Right : String) return Boolean;

   --  Compare two IDL identifiers.
   --  Returns Equal if they are equal (case sensitivity).
   --  Returns Case_Differ if they differ only in case.
   --  Returns Differ otherwise.
   type Ident_Equality is (Differ, Case_Differ, Equal);
   function Idl_Identifier_Equal (Left, Right : String) return Ident_Equality;

   --  Return the idl_token TOK as a string.
   --  Format is "`keyword'", "`+'" (for symbols), "identifier `id'"
   function Image (Tok : Idl_Token) return String;
end Tokens;


