with Ada.Text_IO;
with GNAT.OS_Lib;

package body Idl_Fe.Errors is

   -------------------------
   --  Location handling  --
   -------------------------

   ---------------------
   --  Nat_To_String  --
   ---------------------
   function Nat_To_String (Val : Natural) return String is
      Res : String := Natural'Image (Val);
   begin
      return Res (2 .. Res'Last);
   end Nat_To_String;

   ------------------------
   --  Display_Location  --
   ------------------------
   function Display_Location (Loc : in Location) return String is
   begin
      if Loc.Filename /= null then
         if Loc.Dirname /= null then
            return "line " &
              Nat_To_String (Loc.Line) &
              ", column " &
              Nat_To_String (Loc.Col) &
              " of file " &
              Loc.Dirname.all &
              GNAT.OS_Lib.Directory_Separator &
              Loc.Filename.all;
         else
            return "line " &
              Nat_To_String (Loc.Line) &
              ", column " &
              Nat_To_String (Loc.Col) &
              " of file " &
              Loc.Filename.all;
         end if;
      else
         return "line " &
           Nat_To_String (Loc.Line) &
           ", column " &
           Nat_To_String (Loc.Col);
      end if;
   end Display_Location;



   ----------------------
   --  Error handling  --
   ----------------------

   --  counters for errors and warnings
   Error_Count : Natural := 0;
   Warning_Count : Natural := 0;

   ---------------------
   --  Display_Error  --
   ---------------------
   procedure Display_Error (Message : in String;
                            Level : in Error_Kind;
                            Loc : Location) is
   begin
      case Level is
         when Fatal =>
            Ada.Text_IO.Put ("FATAL ERROR occured");
         when Error =>
            Ada.Text_IO.Put ("ERROR occured");
         when Warning =>
            Ada.Text_IO.Put ("WARNING occured");
      end case;
      if Loc.Line > 0 then
         Ada.Text_IO.Put (" at " & Display_Location (Loc));
      end if;
      Ada.Text_IO.New_Line;
      Ada.Text_IO.Put ("    ");
      Ada.Text_IO.Put_Line (Message);
      Ada.Text_IO.New_Line;
   end Display_Error;

   -------------------
   --  Lexer_Error  --
   -------------------
   procedure Lexer_Error (Message : in String;
                          Level : in Error_Kind;
                          Loc : Errors.Location)is
   begin
      case Level is
         when Fatal =>
            null;
         when Error =>
            Error_Count := Error_Count + 1;
         when Warning =>
            Warning_Count := Warning_Count + 1;
      end case;
      Display_Error (Message, Level, Loc);
      if Level = Fatal then
         raise Fatal_Error;
      end if;
   end Lexer_Error;

   --------------------
   --  Parser_Error  --
   --------------------
   procedure Parser_Error (Message : in String;
                           Level : in Error_Kind;
                           Loc : in Location)is
   begin
      case Level is
         when Fatal =>
            null;
         when Error =>
            Error_Count := Error_Count + 1;
         when Warning =>
            Warning_Count := Warning_Count + 1;
      end case;
      Display_Error (Message, Level, Loc);
      if Level = Fatal then
         raise Fatal_Error;
      end if;
   end Parser_Error;

   ----------------
   --  Is_Error  --
   ----------------
   function Is_Error return Boolean is
   begin
      return Error_Count > 0;
   end Is_Error;

   ------------------
   --  Is_Warning  --
   ------------------
   function Is_Warning return Boolean is
   begin
      return Warning_Count > 0;
   end Is_Warning;

   --------------------
   --  Error_Number  --
   --------------------
   function Error_Number return Natural is
   begin
      return Error_Count;
   end Error_Number;

   ----------------------
   --  Warning_Number  --
   ----------------------
   function Warning_Number return Natural is
   begin
      return Warning_Count;
   end Warning_Number;

end Idl_Fe.Errors;
