with CORBA;

with CosNaming.BindingIterator.Helper;
with CosNaming.BindingIterator.Skel;
pragma Elaborate (CosNaming.BindingIterator.Skel);

with Ada.Unchecked_Deallocation;

with Broca.Server_Tools;

with GNAT.Task_Lock; use GNAT.Task_Lock;

package body CosNaming.BindingIterator.Impl is

   Null_Binding : constant Binding := (To_Sequence (0), Nobject);

   procedure Free is
      new Ada.Unchecked_Deallocation
     (Bindings.Element_Array, Binding_Element_Array_Ptr);

   ------------
   -- Create --
   ------------

   function Create return Object_Ptr is
      Obj : Object_Ptr;

   begin
      Obj := new Object;
      Obj.Self := Obj;
      return Obj;
   end Create;

   -------------
   -- Destroy --
   -------------

   procedure Destroy
     (Self : access Object) is
   begin
      Lock;
      if Self.Table /= null then
         Free (Self.Table);
      end if;
      Unlock;
   end Destroy;

   --------------
   -- Next_One --
   --------------

   procedure Next_One
     (Self    : access Object;
      B       : out CosNaming.Binding;
      Returns : out CORBA.Boolean) is
   begin
      Lock;
      if Self.Index <= Self.Table'Last then
         B := Self.Table (Self.Index);
         Self.Index := Self.Index + 1;
         Returns := True;

      else
         B := Null_Binding;
         Returns := False;
      end if;
      Unlock;
   end Next_One;

   ------------
   -- Next_N --
   ------------

   procedure Next_N
     (Self     : access Object;
      How_Many : in CORBA.Unsigned_Long;
      BL       : out CosNaming.BindingList;
      Returns  : out CORBA.Boolean)
   is
      First : Natural renames Self.Index;
      Last  : Natural;

   begin
      Lock;
      Last := Self.Index + Natural (How_Many) - 1;
      if Last <= Self.Table'Last then
         BL := BindingList (Bindings.To_Sequence (Self.Table (First .. Last)));
         Self.Index := Last;
         Returns := True;

      else
         Returns := False;
      end if;
      Unlock;
   end Next_N;

end CosNaming.BindingIterator.Impl;
