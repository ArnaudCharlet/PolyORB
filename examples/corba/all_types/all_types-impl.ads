------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--                       A L L _ T Y P E S . I M P L                        --
--                                                                          --
--                                 S p e c                                  --
--                                                                          --
--         Copyright (C) 2002-2012, Free Software Foundation, Inc.          --
--                                                                          --
-- This is free software;  you can redistribute it  and/or modify it  under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  This software is distributed in the hope  that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for  more details.                                               --
--                                                                          --
-- You should have received a copy of the GNU General Public License and    --
-- a copy of the GCC Runtime Library Exception along with this program;     --
-- see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see    --
-- <http://www.gnu.org/licenses/>.                                          --
--                                                                          --
--                  PolyORB is maintained by AdaCore                        --
--                     (email: sales@adacore.com)                           --
--                                                                          --
------------------------------------------------------------------------------

with CORBA;
with CORBA.Object;
with PortableServer;

package all_types.Impl is

   --  This is simply used to define the operations.

   type Object is new PortableServer.Servant_Base with record
      Attr_My_Color : Color := Blue;
      Attr_Counter  : CORBA.Long := 0;
   end record;

   function echoBoolean
     (Self : access Object;
      arg : CORBA.Boolean) return CORBA.Boolean;

   function echoShort
     (Self : access Object;
      arg : CORBA.Short) return CORBA.Short;

   function echoLong
     (Self : access Object;
      arg : CORBA.Long) return CORBA.Long;

   function echoUShort
     (Self : access Object;
      arg : CORBA.Unsigned_Short) return CORBA.Unsigned_Short;

   function echoULong
     (Self : access Object;
      arg : CORBA.Unsigned_Long) return CORBA.Unsigned_Long;

   function echoULLong
     (Self : access Object;
      arg : CORBA.Unsigned_Long_Long) return CORBA.Unsigned_Long_Long;

   function echoFloat
     (Self : access Object;
      arg : CORBA.Float) return CORBA.Float;

   function echoDouble
     (Self : access Object;
      arg : CORBA.Double) return CORBA.Double;

   function echoChar
     (Self : access Object;
      arg : CORBA.Char) return CORBA.Char;

   function echoWChar
     (Self : access Object;
      arg : CORBA.Wchar) return CORBA.Wchar;

   function echoOctet
     (Self : access Object;
      arg : CORBA.Octet) return CORBA.Octet;

   function echoString
     (Self : access Object;
      arg : CORBA.String) return CORBA.String;

   function echoWString
     (Self : access Object;
      arg : CORBA.Wide_String) return CORBA.Wide_String;

   function echoRef
     (Self : access Object;
      arg : all_types.Ref) return all_types.Ref'Class;

   function echoObject
     (Self : access Object;
      arg  : CORBA.Object.Ref) return CORBA.Object.Ref;

   function echoOtherAllTypes
     (Self : access Object;
      arg  : all_types.otherAllTypes) return all_types.otherAllTypes'Class;

   function echoOtherObject
     (Self : access Object;
      arg  : all_types.otherObject) return all_types.otherObject;

   function echoBoundedStr
     (Self : access Object;
      arg  : all_types.BoundedStr) return all_types.BoundedStr;

   function echoBoundedWStr
     (Self : access Object;
      arg  : all_types.BoundedWStr) return all_types.BoundedWStr;

   function echoColor
     (Self : access Object;
      arg  : Color) return Color;

   function echoRainbow
     (Self : access Object;
      arg  : Rainbow) return Rainbow;

   function echoArray
     (Self : access Object;
      Arg : simple_array) return simple_array;

   function echoMatrix
     (Self : access Object;
      arg : matrix) return matrix;

   function echoBigMatrix
     (Self : access Object;
      arg : bigmatrix) return bigmatrix;

   function echoNestedArray
     (Self : access Object;
      Arg : nested_array) return nested_array;

   function echoSixteenKb
     (Self : access Object;
      arg : sixteenKb) return sixteenKb;

   procedure testException
     (Self : access Object;
      info : CORBA.Long;
      why  : CORBA.String);

   procedure testUnknownException
     (Self : access Object;
      arg : CORBA.Long);

   procedure testSystemException
     (Self : access Object;
      arg : CORBA.Long);

   function echoStruct
     (Self : access Object;
      arg  : simple_struct) return simple_struct;

   function echoArrayStruct
     (Self : access Object;
      arg  : array_struct) return array_struct;

   function echoNestedStruct
     (Self : access Object;
      arg  : nested_struct) return nested_struct;

   function echoUnion
     (Self : access Object;
      arg : myUnion) return myUnion;

   function echoUnionEnumSwitch
     (Self : access Object;
      arg : myUnionEnumSwitch) return myUnionEnumSwitch;

   function echoNoMemberUnion
     (Self : access Object;
      arg : noMemberUnion) return noMemberUnion;

   function echoUsequence
     (Self : access Object;
      arg : U_sequence) return U_sequence;

   function echoBsequence
     (Self : access Object;
      arg : B_sequence) return B_sequence;

   function echoUnionSequence
     (Self : access Object;
      arg : unionSequence) return unionSequence;

   function echoMoney
     (Self : access Object;
      Arg  : Money) return Money;

   function echoAny
     (Self : access Object;
      Arg  : CORBA.Any) return CORBA.Any;

   procedure set_MyColor
     (Self : access Object;
      arg : Color);

   function get_myColor
     (Self : access Object)
     return Color;

   function get_Counter
     (Self : access Object) return CORBA.Long;

   procedure StopServer (Self : access Object);

end all_types.Impl;
