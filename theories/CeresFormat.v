
(* begin hide *)
From Coq Require Import
  List ZArith Ascii String.

From Ceres Require Import
  CeresString
  CeresS.
(* end hide *)

(** Helper for [string_of_sexp]. *)
Local Definition dstring_of_sexp {A} (dstring_A : A -> DString.t)
  : sexp A -> DString.t
  := fix _to_dstring (x : sexp A) : DString.t :=
    match x with
    | Atom a => dstring_A a
    | List nil => "()"%string
    | List (x :: xs) => fun s0 =>
        (  "("
        :: _to_dstring x
             (fold_right (fun x => " "%char ++ _to_dstring x)%dstring
                (")" :: s0)
                xs))%string
    end%dstring.

(** Convert a [sexp] to a [string]. *)
Definition string_of_sexp {A} (string_A : A -> string) (x : sexp A) : string :=
  dstring_of_sexp string_A x ""%string.

(** Convert an [atom] to a [string]. *)
Definition string_of_atom (a : atom) : string :=
  match a with
  | _Num n => string_of_Z n
  | _Str s => escape_string s
  | _Raw s => s
  end.

(** Convert a [sexp atom] to a [string]. *)
Definition string_of_sexpa : sexp atom -> string :=
  string_of_sexp string_of_atom.