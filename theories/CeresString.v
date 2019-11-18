(** * String utilities *)

(* begin hide *)
From Coq Require Import
  Bool DecidableClass List Arith ZArith NArith Ascii String Decimal DecimalString.
(* end hide *)

Infix "::" := String : string_scope.

Local Open Scope lazy_bool_scope.

Definition ascii_eqb (a b : ascii) : bool :=
 match a, b with
 | Ascii a0 a1 a2 a3 a4 a5 a6 a7,
   Ascii b0 b1 b2 b3 b4 b5 b6 b7 =>
    Bool.eqb a0 b0 &&& Bool.eqb a1 b1 &&& Bool.eqb a2 b2 &&& Bool.eqb a3 b3
    &&& Bool.eqb a4 b4 &&& Bool.eqb a5 b5 &&& Bool.eqb a6 b6 &&& Bool.eqb a7 b7
 end.

Program Instance Decidable_eq_ascii : forall (a b : ascii), Decidable (a = b) :=
  { Decidable_witness := ascii_eqb a b }.
Next Obligation with auto.
  split; intros.
  - destruct a, b; simpl in H.
    destruct (eqb b0 b  ) eqn:H0,
             (eqb b1 b8 ) eqn:H1,
             (eqb b2 b9 ) eqn:H2,
             (eqb b3 b10) eqn:H3,
             (eqb b4 b11) eqn:H4,
             (eqb b5 b12) eqn:H5,
             (eqb b6 b13) eqn:H6,
             (eqb b7 b14) eqn:H7;
    try discriminate H.
    f_equal; apply eqb_prop...
  - rewrite H.
    destruct b.
    simpl.
    repeat rewrite eqb_reflx...
Qed.

Fixpoint eqb s1 s2 : bool :=
  match s1, s2 with
  | EmptyString, EmptyString => true
  | String c1 s1', String c2 s2' => ascii_eqb c1 c2 &&& eqb s1' s2'
  | _,_ => false
  end.

Program Instance Decidable_eq_string : forall (s1 s2 : string), Decidable (s1 = s2) :=
  { Decidable_witness := eqb s1 s2 }.
Next Obligation with auto.
  split.
  - generalize dependent s2.
    induction s1.
    + induction s2; intros...
      discriminate H.
    + induction s2; intros; try discriminate H.
      simpl in H.
      destruct (ascii_eqb a a0) eqn:Heqa.
      * f_equal...
        apply Decidable_spec...
      * discriminate H.
  - intros.
    generalize dependent s1.
    induction s2; intros; subst...
    simpl.
    replace (ascii_eqb a a) with true...
    symmetry.
    apply Decidable_eq_ascii_obligation_1...
Qed.

Fixpoint _string_reverse (r s : string) : string :=
  match s with
  | "" => r
  | c :: s => _string_reverse (c :: r) s
  end%string.

Definition string_reverse : string -> string := _string_reverse "".

(** Separate elements with commas. *)
Fixpoint comma_sep (xs : list string) : string :=
  match xs with
  | nil => ""
  | x :: nil => x
  | x :: xs => x ++ ", " ++ comma_sep xs
  end.

Notation newline := ("010" :: "")%string.

(** Is a character printable? The character is given by its ASCII code. *)
Definition is_printable (n : nat) : bool :=
  (  (n <? 32)%nat (* 32 = SPACE *)
  || (126 <? n)%nat (* 126 = ~ *)
  ).

Definition is_whitespace (c : ascii) : bool :=
  match c with
  | " " | "010" | "013" => true
  | _ => false
  end%char.

(** ** Escape string *)

(** The [ascii] units digit of a [nat]. *)
Local Definition _units_digit (n : nat) : ascii :=
  ascii_of_nat ((n mod 10) + 48 (* 0 *)).

(** The hundreds, tens, and units digits of a [nat]. *)
Local Definition _three_digit (n : nat) : string :=
  let n0 := _units_digit n in
  let n1 := _units_digit (n / 10) in
  let n2 := _units_digit (n / 100) in
  (n2 :: n1 :: n0 :: EmptyString).

(** Helper for [escape_string] *)
Local Fixpoint _escape_string (s : string) : string :=
  match s with
  | EmptyString => """"
  | (c :: s')%string =>
    let escaped_s' := _escape_string s' in
    if ascii_dec c "009" (* 9 = TAB *) then
      "\" :: "t" :: escaped_s'
    else if ascii_dec c "010" (* 10 = NEWLINE *) then
      "\" :: "n" :: escaped_s'
    else if ascii_dec c "013" (* 13 = CARRIAGE RETURN *) then
      "\" :: "r" :: escaped_s'
    else if ascii_dec c """" (* DOUBLEQUOTE *) then
      "\" :: """" :: escaped_s'
    else if ascii_dec c "\" (* BACKSLASH *) then
      "\" :: "\" :: escaped_s'
    else
      let n := nat_of_ascii c in
      if is_printable n then
        "\" :: _three_digit n ++ escaped_s'
      else
        String c escaped_s'
  end.

(** Escape a string so it can be shown in a terminal. *)
Definition escape_string (s : string) : string :=
  String """" (_escape_string s).

(** ** Unescape string *)

(** Read an [ascii] digit into a [nat]. *)
Definition digit_of_ascii (c : ascii) : option nat :=
  let n := nat_of_ascii c in
  if ((48 <=? n)%nat && (n <=? 57)%nat)%bool then
    Some (n - 48)
  else
    None.

(** The inverse of [three digit]. *)
Local Definition _unthree_digit (c2 c1 c0 : ascii) : option ascii :=
  let doa := digit_of_ascii in
  match doa c2, doa c1, doa c0 with
  | Some n2, Some n1, Some n0 =>
    Some (ascii_of_nat (n2 * 100 + n1 * 10 + n0))
  | _, _, _ => None
  end.

(** Helper for [unescape_string]. *)
Local Fixpoint _unescape_string (s : string) : option string :=
  match s with
  | String c s' =>
    if ascii_dec c """" then
      match s' with
      | EmptyString => Some EmptyString
      | _ => None
      end
    else if ascii_dec c "\" then
      match s' with
      | String c2 s'' =>
        if ascii_dec c2 "n" then
          option_map (String "010") (_unescape_string s'')
        else if ascii_dec c2 "r" then
          option_map (String "013") (_unescape_string s'')
        else if ascii_dec c2 "t" then
          option_map (String "009") (_unescape_string s'')
        else if ascii_dec c2 "\" then
          option_map (String "\") (_unescape_string s'')
        else if ascii_dec c2 """" then
          option_map (String """") (_unescape_string s'')
        else
          match s'' with
          | String c1 (String c0 s''') =>
            match _unthree_digit c2 c1 c0 with
            | Some c' => option_map (String c')
                                    (_unescape_string s''')
            | None => None
            end
          | _ => None
          end
      | _ => None
      end
    else
      option_map (String c) (_unescape_string s')
  | _ => None
  end.

(** The inverse of [escape_string]. *)
Definition unescape_string (s : string) : option string :=
  match s with
  | ("""" :: s')%string => _unescape_string s'
  | (_ :: _)%string => None
  | EmptyString => None
  end.

(** ** Convert numbers to string *)

Import NilEmpty.

Definition string_of_nat (n : nat) : string :=
  string_of_uint (Nat.to_uint n).

Definition string_of_Z (n : Z) : string :=
  string_of_int (Z.to_int n).

Definition string_of_N (n : N) : string :=
  string_of_Z (Z.of_N n).

Definition string_of_bool (b : bool) : string :=
  match b with
  | true => "true"
  | false => "false"
  end.

Module DString.

(** Difference lists for fast append. *)
Definition t : Type := string -> string.

Definition of_string (s : string) : t := fun s' => (s ++ s')%string.
Definition of_ascii (c : ascii) : t := fun s => (c :: s)%string.
Definition app_string : t -> string -> string := id.

End DString.

Coercion DString.of_string : string >-> DString.t.
Coercion DString.of_ascii : ascii >-> DString.t.

(* Declare Scope dstring_scope. *)
Delimit Scope dstring_scope with dstring.
Bind Scope dstring_scope with DString.t.
Notation "a ++ b" := (fun s => DString.app_string a (DString.app_string b s))
  : dstring_scope.

