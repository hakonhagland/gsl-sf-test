%module "GSL::SF"
%include "typemaps.i"

%{
#include "gsl/gsl_types.h"
#include "gsl/gsl_roots.h"
#define SWIG_FDFSOLVER_PACKAGE_NAME "GSL::FdfSolver"    
#define SWIG_FDFSOLVER_PACKAGE_NAME_SOLVER \
  SWIG_FDFSOLVER_PACKAGE_NAME "::Solver"    
#define SWIG_FDFSOLVER_GUTS \
  SWIG_FDFSOLVER_PACKAGE_NAME "::_guts"    
#define SWIG_FDFSOLVER_VAR_F SWIG_FDFSOLVER_GUTS "::f"    
#define SWIG_FDFSOLVER_VAR_DF SWIG_FDFSOLVER_GUTS "::df"    
#define SWIG_FDFSOLVER_VAR_FDF SWIG_FDFSOLVER_GUTS "::fdf"    
#define SWIG_FDFSOLVER_VAR_PARAMS SWIG_FDFSOLVER_GUTS "::params"    
#define SWIG_FDFSOLVER_PACKAGE_NAME_DESTROY_FUNC    \
    SWIG_FDFSOLVER_PACKAGE_NAME_SOLVER "::DESTROY"
#define SWIG_FDFSOLVER_FIELD_NAME_SOLVER "solver"    

    IV swig_fdfsolver_get_hash_int(HV *hash, const char *key) {
        SV * key_sv = newSVpv (key, strlen (key));
        IV value;
        if (hv_exists_ent (hash, key_sv, 0)) {
            HE *he = hv_fetch_ent (hash, key_sv, 0, 0);
            SV *val = HeVAL (he);
            if (SvIOK (val)) {
                value = SvIV (val);
            }
            else {
                croak("Value of hash key '%s' is not a number", key);
            }
        }
        else {
            croak("The hash key for '%s' doesn't exist", key);
        }
        return value;
    }


    XS(XS_GSL__FdfSolver__Solver_DESTROY) {
        dVAR; dXSARGS;
        SV *self = ST(0);
        HV *hv = (HV *) SvRV(self);
        const char *name = SWIG_FDFSOLVER_FIELD_NAME_SOLVER;
        IV solver_addr = swig_fdfsolver_get_hash_int(hv, name);
        gsl_root_fdfsolver *solver = (gsl_root_fdfsolver *) INT2PTR(SV*, solver_addr);
        gsl_root_fdfsolver_free( solver );
        XSRETURN_EMPTY;
    }
    
    SV *swig_fdfsolver_create(gsl_root_fdfsolver *solver) {
       HV *hash = newHV();
       SV *self = newRV_noinc( (SV *)hash ); // we don't want ownership of "hash"
       SV *sv = newSViv(PTR2IV(solver));
       const char *name = SWIG_FDFSOLVER_FIELD_NAME_SOLVER;
       const char *pack_name = SWIG_FDFSOLVER_PACKAGE_NAME_SOLVER;
       hv_store (hash, name, strlen(name), sv, 0);
       self = sv_bless(self, gv_stashpv( pack_name, GV_ADD ) );
       const char *destroy_name = SWIG_FDFSOLVER_PACKAGE_NAME_DESTROY_FUNC;
       newXS(destroy_name, XS_GSL__FdfSolver__Solver_DESTROY,  (char*)__FILE__);
       return self;
    }

    double swig_fdfsolver_callback_scalar_context (
        SV *callback, double x, SV *params
    ) {
        dSP;     /* declares a local copy of stack pointer */
        if (callback == NULL ) {
            croak("No callback registered!");
        }
        ENTER;
        SAVETMPS;
        PUSHMARK(SP);
        EXTEND(SP, 2);
        PUSHs(sv_2mortal(newSVnv(x)));
        PUSHs(sv_2mortal(newSVsv(params)));
        PUTBACK;
        int count = call_sv(callback, G_SCALAR);  /* call the Perl callback */
        SPAGAIN;
        if (count != 1) {
            croak("Bad return value from callback: expected 1 value, got %d", count);
        }
        double result = POPn;
        PUTBACK;
        FREETMPS;
        LEAVE;
        return result;
    }

    void swig_fdfsolver_callback_list_context (
        SV *callback, double x, SV *params, double *y, double *dy
    ) {
        dMY_CXT; /* declare MY_CXT */
        dSP;     /* declares a local copy of stack pointer */
        ENTER;
        SAVETMPS;
        PUSHMARK(SP);
        EXTEND(SP, 2);
        PUSHs(sv_2mortal(newSVnv(x)));
        PUSHs(sv_2mortal(newSVsv(params)));
        PUTBACK;
        int count = call_sv(callback, G_ARRAY);  /* call the Perl callback */
        SPAGAIN;
        if (count != 2) {
            croak("Bad return value from callback: expected 2 values, got %d", count);
        }
        *dy = POPn;
        *y = POPn;
        PUTBACK;
        FREETMPS;
        LEAVE;
    }
    
    double swig_fdfsolver_callback_f ( double x, void *params) {
        SV* callback = get_sv( SWIG_FDFSOLVER_VAR_F, GV_ADD );
        SV *perl_params = (SV *) params;
        return swig_fdfsolver_callback_scalar_context( callback, x, perl_params );
    }
    
    double swig_fdfsolver_callback_df ( double x, void *params) {
        SV* callback = get_sv( SWIG_FDFSOLVER_VAR_DF, GV_ADD );
        SV *perl_params = (SV *) params;
        return swig_fdfsolver_callback_scalar_context( callback, x, perl_params );
    }

    void swig_fdfsolver_callback_fdf (
        double x, void *params, double *y, double *dy
    ) {
        SV* callback = get_sv( SWIG_FDFSOLVER_VAR_FDF, GV_ADD );
        SV *perl_params = (SV *) params;
        swig_fdfsolver_callback_list_context( callback, x, perl_params, y, dy );
    }
%}

#define GSL_VAR extern
GSL_VAR const gsl_root_fdfsolver_type  *gsl_root_fdfsolver_newton;

/* The function gsl_root_fdfsolver_alloc() returns a "gsl_root_fdfsolver *",
   We here write a new typemap and encapsulates it and some other internal variables 
   into a perl object that has a DESTROY() function. This means that a call to 
   gsl_root_fdfsolver_free() in Perl to free the memory used by the solver is now
   redundant. Simply letting the returned solver variable go out of scope will 
   call DESTROY() which will in turn call gsl_root_fdfsolver_free().

   The other internal variables in the returned solver object are used to store
   callback information in the input typemap for gsl_root_fdfsolver_set()
*/

%typemap(out)  gsl_root_fdfsolver * {
    SV *self = swig_fdfsolver_create( $1 );
    $result = sv_2mortal(self);
    argvi++;
}

gsl_root_fdfsolver *gsl_root_fdfsolver_alloc (const gsl_root_fdfsolver_type *T);

%typemap(out) gsl_root_fdfsolver *;  // reset typemap

%ignore gsl_function_fdf;

typedef struct {
  double (* f) (double x, void * params);
  double (* df) (double x, void * params);
  void (* fdf) (double x, void * params, double * f, double * df);
  void * params;
} gsl_function_fdf;

%perlcode %{
    package GSL::FdfSolver::gsl_function_fdf;

    sub new {
        my ($class, $f, $df, $fdf, $params ) = @_;

        my $check_ref = sub {
            if ( (ref $_[0]) ne $_[1] ) {
                die sprintf 'Usage: %s:new( $f, $df, $fdf, $params ). '
                . 'Argument %s is not %s reference',
                __PACKAGE__, $_[2], $_[3];
            }
        };
        my $check_subref = sub {
            $check_ref->($_[0], "CODE", $_[1], "code");
        };
        my $check_hashref = sub {
            $check_ref->($_[0], "HASH", $_[1], "hash");
        };
        $check_subref->($f, '$f');
        $check_subref->($df, '$df');
        $check_subref->($fdf, '$fdf');
        $check_hashref->($params, '$params');
        return bless { f => $f, df => $df, fdf => $fdf, params => $params }, $class;
    }
%}

/* The original GSL function gsl_root_fdfsolver_set() takes three input parameters
   We provide a Perl interface to this using only two parameters.
 */

/*%rename(gsl_root_fdfsolver_set) _gsl_root_fdfsolver_set;
int gsl_root_fdfsolver_set(
    gsl_root_fdfsolver *s, gsl_function_fdf *fdf, double root);
*/


