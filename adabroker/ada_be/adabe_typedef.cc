#include <idl.hh>
#include <idl_extern.hh>
#include <adabe.h>


adabe_typedef::adabe_typedef(AST_Type *bt, UTL_ScopedName *n, UTL_StrList *p)
	  : AST_Typedef(bt, n, p),
	    AST_Decl(AST_Decl::NT_typedef, n, p),
	    adabe_name(AST_Decl::NT_typedef, n, p),

{
}

void
adabe_typedef::produce_ads(dep_list with,string &String, string &previousdefinition)
{
  compute_ada_names();
  INDENTATION(String);
  String += "type" + get_ada_name() + "is new ";
  AST_Decl *b  base_type();
  String +=  adabe_name::narrow_from_decl(b)->dump_name(with, &String, &previousdefinition); //virtual method
  String += "\n";
}

void
adabe_typedef::produce_adb(dep_list with,string &String, string &previousdefinition)
{
  if (!is_imported(with)) return get_ada_name();
  return get_ada_full_name();	   
}

void
adabe_typedef::produce_impl_ads(dep_list with,string &String, string &previousdefinition)
{
  produce_ads(with, String, previousdefinition);
}

void
adabe_typedef::produce_impl_adb(dep_list with,string &String, string &previousdefinition)
{
  if (!is_imported(with)) return get_ada_name();
  return get_ada_full_name();
}

IMPL_NARROW_METHODS1(adabe_typedef, AST_Typedef)
IMPL_NARROW_FROM_DECL(adabe_typedef)



