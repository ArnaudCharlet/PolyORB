/*************************************************************************************************
***                              ADA BACK-END COMPILER                                         ***
***                             file:  adabe_union.cc                                          ***
***                                                                                            ***
***      This file provides the implementation of class adabe_union     declared in adabe.h    ***
***   (L 299). This class is the correspondant of the Sun's Front-End class AST_Union .        ***
***   It provides produce functions for each generated file, a constructor and two little      ***
***   functions : dump_name and marshall_name whose job is to print the name of the type.      ***
***                                                                                            ***
***   Copyright 1999                                                                           ***
***   Jean Marie Cottin, Laurent Kubler, Vincent Niebel                                        ***
***                                                                                            ***
***   This is free software; you can redistribute it and/or modify it under terms of the GNU   ***
***   General Public License, as published by the Free Software Foundation.                    ***
***                                                                                            ***
***  This back-end is distributed in the hope that it will be usefull, but WITHOUT ANY         ***
***  WARRANTY; without even the implied waranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR ***
***  PURPOSE.                                                                                  ***
***                                                                                            ***
***  See the GNU General Public License for more details.                                      ***
***                                                                                            ***
***                                                                                            ***
*************************************************************************************************/
#include <adabe.h>

adabe_union::adabe_union(AST_ConcreteType *dt, UTL_ScopedName *n, UTL_StrList *p)
	: AST_Union(dt, n, p),
	  AST_Decl(AST_Decl::NT_union, n, p),
          AST_Structure(AST_Decl::NT_union, n, p),
	  UTL_Scope(AST_Decl::NT_union),
	  adabe_name(AST_Decl::NT_union, n, p)
{
  pd_have_default_case = false;
}

void
adabe_union::produce_ads(dep_list& with, string &body, string &previous)
{
  int count = 0;
  // to count the number of case when the discriminant type is an enum
  
  bool has_default_case = false;
  // to check if there is a default case

  string default_case = "";
  default_case += "         when others =>\n";
  default_case += "            Null;\n";
  // it is the default case
  
  compute_ada_name();
  body += "   type " + get_ada_local_name();
  adabe_name *b = dynamic_cast<adabe_name *>(disc_type());
  b->compute_ada_name();
  string name = b->dump_name(with, previous);
  body += "(Switch : "  + name;
  body += " := " + name + "'first) is record\n";
  body += "      case Switch is\n";
  UTL_ScopeActiveIterator i(this,UTL_Scope::IK_decls);
  while (!i.is_done())
    {
      AST_Decl *d = i.item();
      if (d->node_type() == AST_Decl::NT_union_branch)
	{
	  adabe_union_branch *unionbr = dynamic_cast<adabe_union_branch *>(d);
	  unionbr->produce_ads(with, body, previous, disc_type());
	  if (unionbr->label()->label_kind() == AST_UnionLabel::UL_default)
	    has_default_case = true;
	  count++;
	}
      else throw adabe_internal_error(__FILE__,__LINE__,"Unexpected node in union");
      i.next ();
    }

  if (!has_default_case)
    {
      switch (disc_type()->node_type())
	{
	case AST_Decl::NT_enum:
	  if (count != (dynamic_cast<adabe_enum *>(b)->get_number_value()))
	    set_default_case(true);
	  break;
	case AST_Decl::NT_typedef:
	  if ((count != (dynamic_cast<adabe_typedef *>(b)->get_number_value()))
	      && ((dynamic_cast<adabe_typedef *>(b)->get_number_value()) > 0))
	    set_default_case(true);
	  break;
	default:
	  set_default_case(true);
	  break;
	}
  // case to check if we should add a default case (if it is int, long or char, it's automatically added)
    }
  if (get_default_case()) body += default_case;
  body += "      end case ;\n";
  body += "   end record ;\n";
  body += "   type " + get_ada_local_name() + "_Ptr is access ";
  body += get_ada_local_name() + " ;\n\n";
  body += "   procedure Free is new Ada.Unchecked_Deallocation(";
  body += get_ada_local_name() + ", " + get_ada_local_name ()+ "_Ptr) ;\n\n\n";  
  set_already_defined();
}

void
adabe_union::produce_marshal_ads(dep_list& with, string &body, string &previous)
{
  body += "   procedure Marshall (A : in ";
  body += get_ada_local_name();
  body += " ;\n";
  body += "                       S : in out Netbufferedstream.Object'Class) ;\n\n";

  body += "   procedure UnMarshall (A : out ";
  body += get_ada_local_name();
  body += " ;\n";
  body += "                         S : in out Netbufferedstream.Object'Class) ;\n\n";

  body += "   function Align_Size (A : in ";
  body += get_ada_local_name();
  body += " ;\n";
  body += "                        Initial_Offset : in Corba.Unsigned_Long)\n";
  body += "                        return Corba.Unsigned_Long ;\n\n\n";

  set_already_defined ();
}

void
adabe_union::produce_marshal_adb(dep_list& with, string &body, string &previous)
{
  string disc_name = (dynamic_cast<adabe_name *>(disc_type()))->marshal_name(with, previous); 

  string default_case = "";
  default_case += "         when others =>\n";
  default_case += "            Ada.Exceptions.Raise_Exception(Corba.Dummy_User'Identity,\n";
  default_case += "                                            \"Unchecked case is used in the union\") ;\n";
 
  string marshall = "";
  string unmarshall = "";
  string align_size = "";
  marshall += "   procedure Marshall(A : in ";
  marshall += get_ada_local_name();
  marshall += " ;\n";
  marshall += "                      S : in out Netbufferedstream.Object'Class) is\n";
  marshall += "   begin\n";
  marshall += "      Marshall (A.Switch,S) ;\n";
  marshall += "      case A.Switch is\n";
  
  unmarshall += "   procedure UnMarshall(A : out ";
  unmarshall += get_ada_local_name();
  unmarshall += " ;\n";
  unmarshall += "                        S : in out Netbufferedstream.Object'Class) is\n";
  unmarshall += "      Switch : ";
  unmarshall += disc_name;
  unmarshall += " ;\n";
  unmarshall += "   begin\n";
  unmarshall += "      UnMarshall (Switch,S) ;\n";
  unmarshall += "      declare\n";
  unmarshall += "         Tmp : ";
  unmarshall += get_ada_local_name ();
  unmarshall += "(Switch) ;\n";
  unmarshall += "      begin\n";
  unmarshall += "         case Switch is\n";
  
  align_size += "   function Align_Size (A : in ";
  align_size += get_ada_local_name();
  align_size += " ;\n";
  align_size += "                        Initial_Offset : in Corba.Unsigned_Long)\n";
  align_size += "                        return Corba.Unsigned_Long is\n";
  align_size += "      Tmp : Corba.Unsigned_Long := 0 ;\n";
  align_size += "   begin\n";
  align_size += "      Tmp := Align_Size (A.Switch,Initial_Offset) ;\n";
  align_size += "      case A.Switch is\n";

  UTL_ScopeActiveIterator i(this,UTL_Scope::IK_decls);
  while (!i.is_done())
    {
      AST_Decl *d = i.item();
      if (d->node_type() == AST_Decl::NT_union_branch) {
	dynamic_cast<adabe_union_branch *>(d)->produce_marshal_adb(with,marshall, unmarshall, align_size, disc_type());
      }
      else throw adabe_internal_error(__FILE__,__LINE__,"Unexpected node in union");
      i.next();
    }
  if (get_default_case())
    {
      marshall += default_case;
      align_size += default_case;
      unmarshall += "            when others =>\n";
      unmarshall += "               Ada.Exceptions.Raise_Exception(Corba.Dummy_User'Identity,\n";
      unmarshall += "                                               \"Unchecked case is used in the union\") ;\n";

      with.add("Corba");
      with.add("Ada.Exceptions");
    }
  // we had to add a default case, if called we will raise an exception
  marshall += "      end case ;\n";
  marshall += "   end Marshall ;\n\n";

  unmarshall += "         end case ;\n";
  unmarshall += "      A := Tmp ;\n";
  unmarshall += "      end ;\n";
  unmarshall += "   end Unmarshall ;\n\n";
  
  align_size += "      end case ;\n";
  align_size += "      return Tmp ;\n";
  align_size += "   end Align_Size ;\n\n\n";

  body += marshall;
  body += unmarshall;
  body += align_size;

  set_already_defined();
}

string
adabe_union::dump_name(dep_list& with, string &previous)
{
  if (!is_imported(with))
    {
      if (!is_already_defined())
	{
	  string tmp = "";
	  produce_ads(with, tmp, previous);
	  previous += tmp;
	}
      return get_ada_local_name();
    }
  return get_ada_full_name();	   
}

string
adabe_union::marshal_name(dep_list& with, string &previous)
{
  if (!is_marshal_imported(with))
    {
      if (!is_already_defined())
	{
	  string tmp = "";
	  produce_marshal_adb(with, tmp, previous);
	  previous += tmp;
	}
      return get_ada_local_name();
    }
  return get_ada_full_name();	   
}

IMPL_NARROW_METHODS1(adabe_union, AST_Union)
IMPL_NARROW_FROM_DECL(adabe_union)
IMPL_NARROW_FROM_SCOPE(adabe_union)





