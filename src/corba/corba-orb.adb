--  The following subprograms still have to be implemented :
--
-- create_alias_tc --
-- create_array_tc --
-- create_fixed_tc --
-- create_interface_tc --
-- Create_List --
-- create_native_tc --
-- Create_Policy --
-- create_recursive_sequence_tc --
-- create_sequence_tc --
-- create_string_tc --
-- create_wstring_tc --
-- Get_Default_Context --
-- Get_Service_Information --
-- List_Initial_Services --
-- Perform_Work --
-- Resolve_Initial_References --
-- Shutdown --
-- Work_Pending --

with Ada.Exceptions;

with Sequences.Unbounded;

with PolyORB.Dynamic_Dict;
pragma Elaborate_All (PolyORB.Dynamic_Dict);

with PolyORB.ORB;
with PolyORB.ORB.Task_Policies;
with PolyORB.Objects;
with PolyORB.References.IOR;
with PolyORB.Setup;
with PolyORB.Log;
pragma Elaborate_All (PolyORB.Log);

package body CORBA.ORB is

   use PolyORB.Log;
   use PolyORB.ORB.Task_Policies;
   use PolyORB.ORB;
   use PolyORB.Setup;

   package L is new PolyORB.Log.Facility_Log ("corba.orb");
   procedure O (Message : in Standard.String; Level : Log_Level := Debug)
     renames L.Output;

   package Referenced_Objects is
      new PolyORB.Dynamic_Dict (CORBA.Object.Ref);
   --  For initial references.

   ---------------------
   -- create_alias_tc --
   ---------------------

   function create_alias_tc
     (Id            : in CORBA.RepositoryId;
      Name          : in CORBA.Identifier;
      Original_Type : in CORBA.TypeCode.Object)
      return CORBA.TypeCode.Object
   is
   begin
      raise PolyORB.Not_Implemented;
      return create_alias_tc (Id, Name, Original_Type);
   end create_alias_tc;

   ---------------------
   -- create_array_tc --
   ---------------------

   function create_array_tc
     (Length       : in CORBA.Unsigned_Long;
      Element_Type : in CORBA.TypeCode.Object)
      return CORBA.TypeCode.Object
   is
   begin
      raise PolyORB.Not_Implemented;
      return create_array_tc (Length, Element_Type);
   end create_array_tc;

   ---------------------
   -- create_fixed_tc --
   ---------------------

   function create_fixed_tc
     (IDL_Digits : in CORBA.Unsigned_Short;
      scale      : in CORBA.Short)
      return CORBA.TypeCode.Object
   is
   begin
      raise PolyORB.Not_Implemented;
      return create_fixed_tc (IDL_Digits, scale);
   end create_fixed_tc;

   -------------------------
   -- create_interface_tc --
   -------------------------

   function create_interface_tc
     (Id   : in CORBA.RepositoryId;
      Name : in CORBA.Identifier)
      return CORBA.TypeCode.Object
   is
   begin
      raise PolyORB.Not_Implemented;
      return create_interface_tc (Id, Name);
   end create_interface_tc;

   -----------------
   -- Create_List --
   -----------------

   procedure Create_List
     (Count    : in     CORBA.Long;
      New_List :    out CORBA.NVList.Ref)
   is
   begin
      if Count /= 0 then
         raise PolyORB.Not_Implemented;
         --  XXX How should the list be populated?
      else
         CORBA.NVList.Create (New_List);
      end if;
   end Create_List;

   ----------------------
   -- create_native_tc --
   ----------------------

   function create_native_tc
     (Id   : in RepositoryId;
      Name : in Identifier)
      return CORBA.TypeCode.Object
   is
   begin
      raise PolyORB.Not_Implemented;
      return create_native_tc (Id, Name);
   end create_native_tc;

   -------------------
   -- Create_Policy --
   -------------------

   procedure Create_Policy
     (The_Type : in PolicyType;
      Val      : Any)
   is
   begin
      null;
   end Create_Policy;

   ----------------------------------
   -- create_recursive_sequence_tc --
   ----------------------------------

   function create_recursive_sequence_tc
     (Bound  : in CORBA.Unsigned_Long;
      Offset : in CORBA.Unsigned_Long)
      return CORBA.TypeCode.Object
   is
   begin
      raise PolyORB.Not_Implemented;
      return create_recursive_sequence_tc (Bound, Offset);
   end create_recursive_sequence_tc;

   ------------------------
   -- create_sequence_tc --
   ------------------------

   function create_sequence_tc
     (Bound        : in CORBA.Unsigned_Long;
      Element_Type : in CORBA.TypeCode.Object)
      return CORBA.TypeCode.Object
   is
   begin
      raise PolyORB.Not_Implemented;
      return create_sequence_tc (Bound, Element_Type);
   end create_sequence_tc;

   ----------------------
   -- create_string_tc --
   ----------------------

   function create_string_tc
     (Bound : in CORBA.Unsigned_Long)
      return CORBA.TypeCode.Object
   is
   begin
      raise PolyORB.Not_Implemented;
      return create_string_tc (Bound);
   end create_string_tc;

   -----------------------
   -- create_wstring_tc --
   -----------------------

   function create_wstring_tc
     (Bound : in CORBA.Unsigned_Long)
      return CORBA.TypeCode.Object
   is
   begin
      raise PolyORB.Not_Implemented;
      return create_wstring_tc (Bound);
   end create_wstring_tc;

   -------------------------
   -- Get_Default_Context --
   -------------------------

   function Get_Default_Context
      return CORBA.Context.Ref
   is
   begin
      raise PolyORB.Not_Implemented;
      return Get_Default_Context;
   end Get_Default_Context;

   -----------------------------
   -- Get_Service_Information --
   -----------------------------

   procedure Get_Service_Information
     (Service_Type        : in     CORBA.ServiceType;
      Service_Information :    out ServiceInformation;
      Returns             :    out CORBA.Boolean)
   is
   begin
      raise PolyORB.Not_Implemented;
   end Get_Service_Information;

   ---------------------------
   -- List_Initial_Services --
   ---------------------------

   function List_Initial_Services return ObjectIdList is
   begin
      raise PolyORB.Not_Implemented;
      return List_Initial_Services;
   end List_Initial_Services;

   ------------------
   -- Perform_Work --
   ------------------

   procedure Perform_Work is
   begin
      Perform_Work (The_ORB);
   end Perform_Work;

   --------------------------------
   -- Resolve_Initial_References --
   --------------------------------

   function Resolve_Initial_References
     (Identifier : ObjectId)
     return CORBA.Object.Ref
   is
      Id : constant Standard.String
        := To_Standard_String (Identifier);
   begin
      return Referenced_Objects.Lookup (Id);
   exception
      when E : others =>
         pragma Debug
           (O ("Got exception while looking up " & Id & ":"));
         pragma Debug (O (Ada.Exceptions.Exception_Information (E)));
         raise CORBA.InvalidName;
   end Resolve_Initial_References;

   ---------
   -- Run --
   ---------

   procedure Run is
   begin
      PolyORB.ORB.Run (The_ORB, May_Poll => True);
   end Run;

   --------------
   -- Shutdown --
   --------------

   procedure Shutdown (Wait_For_Completion : in Boolean) is
   begin
      Shutdown (The_ORB, Wait_For_Completion);
   end Shutdown;

   ----------------------
   -- Object_To_String --
   ----------------------

   function Object_To_String (Obj : in CORBA.Object.Ref'Class)
      return CORBA.String is
   begin
      return PolyORB.References.IOR.Object_To_String
        ((Ref => CORBA.Object.To_PolyORB_Ref (Obj)));
   end Object_To_String;

   ----------------------
   -- String_To_Object --
   ----------------------

   procedure String_To_Object
     (From : in     CORBA.String;
      To   : in out CORBA.Object.Ref'Class)
   is
      IOR : constant PolyORB.References.IOR.IOR_Type
        := PolyORB.References.IOR.String_To_Object (From);
   begin
      CORBA.Object.Set
        (To, PolyORB.References.Entity_Of (IOR.Ref));
   end String_To_Object;

   ------------------
   -- Work_Pending --
   ------------------

   function Work_Pending return Boolean is
   begin
      return Work_Pending (The_ORB);
   end Work_Pending;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize
     (ORB_Name : in Standard.String)
   is
      My_Policy : Tasking_Policy_Access;
   begin
      if The_ORB /= null then
         raise Initialization_Failure;
      end if;
      My_Policy := new No_Tasking;
      --  ??? Must implement other policies !!

      The_ORB := new PolyORB.ORB.ORB_Type (My_Policy);
      PolyORB.ORB.Create (The_ORB.all);
   end Initialize;

   ----------------------
   -- Create_Reference --
   ----------------------

   function Create_Reference
     (Object : in CORBA.Object.Ref;
      Typ : in Standard.String)
     return PolyORB.References.Ref
   is
      Result : PolyORB.References.Ref;

      Oid    : PolyORB.Objects.Object_Id_Access
        := new PolyORB.Objects.Object_Id'
        (CORBA.Object.To_PolyORB_Object (Object));
   begin
      if The_ORB = null then
         raise Internal;
      end if;

      PolyORB.ORB.Create_Reference
        (The_ORB, Oid, Typ, Result);

      return Result;
   end Create_Reference;

end CORBA.ORB;

