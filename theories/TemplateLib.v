Require Import List Arith Ascii String Fin.
Require Import MetaCoq.Template.All.
Import ListNotations.
Set Universe Polymorphism.
Set Primitive Projections.

Local Open Scope string_scope.

Module Import TMNotations.

Notation TM := TemplateMonad.
Notation "x <- u ;; k" := (tmBind u (fun x => k))
  (at level 60, u at next level, right associativity) : template_scope.
Infix ">>=" := tmBind (at level 50, left associativity) : template_scope.
Notation "u ;; v" := (tmBind u (fun _ => v)) (at level 60, right associativity) : template_scope.
Delimit Scope template_scope with template.
Open Scope template_scope.

Notation tInd_ s := (tInd (mkInd s _) _).
Notation tCon_ s n := (tConstruct (mkInd s _) n _).

End TMNotations.

Quote Definition q_nil := @nil.
Quote Definition q_cons := @cons.

(* Get the [one_inductive_body] from a [mutual_inductive_body].
   Fails if there is more than one. *)
Definition get_ind_body (tyDef : mutual_inductive_body)
  : TM one_inductive_body :=
  match ind_bodies tyDef with
  | [body] => tmReturn body
  | _ => tmFail "Unimplemented (mutually recursive types)"
  end.

Definition tmTraverse {A B} (f : A -> TM B)
  : list A -> TM (list B) :=
  fix _traverse xs :=
    match xs with
    | [] => tmReturn []
    | x :: xs =>
      y <- f x ;;
      ys <- _traverse xs ;;
      tmReturn (y :: ys)
    end.

Definition when (b : bool) (u : TM unit) : TM unit :=
  if b then u else tmReturn tt.

Definition _tMatch
    (tyDef : mutual_inductive_body) (i : inductive) (ti : term) (ys : list term)
    (x : term) (z : term)
    (branch : ident -> context -> term -> TM term)
  : TM term :=
  tyBody <- get_ind_body tyDef ;;
  let params := firstn (ind_npars tyDef) ys in
  let tyBody' :=
    subst0 (rev' params) (remove_arity (ind_npars tyDef) (ind_type tyBody)) in
  let (ctx', ty0) := decompose_prod_assum [] tyBody' in
  let motive := it_mkLambda_or_LetIn ctx'
    (let n := List.length ctx' in
     tLambda
       nAnon
       (mkApps (lift0 n (tApp ti params)) (List.map tRel (rev' (seq 0 n))))
       (lift0 n z)) in
  let mkBranch : _ -> TM (nat * term) := fun '(i, t, a) =>
    let t'' := subst0 (rev' (ti :: params)) (remove_arity (ind_npars tyDef) t) in
    let '(ctx, t') := decompose_prod_assum [] t'' in
    tb <- branch i ctx t' ;;
    let u := it_mkLambda_or_LetIn ctx tb in
    tmReturn (a, u) in
  branches <- tmTraverse mkBranch (ind_ctors tyBody) ;;
  tmReturn (tCase (i, 0) motive x branches).

(* [match x : y return z with ... end]
   - [x]: Scrutinee
   - [y]: Type of scrutinee
   - [z]: "Motive", return type of the [match]
   - The [branch] function is given, for every branch, the name of the
     constructor, its fields as a [context], the result type of the
     constructor [term], and produces the [term] corresponding to the branch.
 *)
Definition tMatch
    (x : term) (y : term) (z : term)
    (branch : ident -> context -> term -> TM term)
  : TM term :=
  let go i ti ys :=
    let name := inductive_mind i in
    tyDef <- tmQuoteInductive name ;;
    _tMatch tyDef i ti ys x z branch
  in
  match y with
  | tApp (tInd i _ as ti) ys => go i ti ys
  | tInd i _ as ti => go i ti []
  | _ => tmFail "Not matching an inductive"
  end.

Definition getName {A : Type} (a : A) : TM kername :=
  qa <- tmQuote a ;;
  match qa with
  | tConst name _ => tmReturn name
  | _ => tmFail "Not a constant"
  end.

Definition assert_else (b : bool) (s : string) : TM unit :=
  if b then tmReturn tt else tmFail s.

Definition isSort : term -> bool := fun t =>
  match t with
  | tSort _ => true
  | _ => false
  end.

(* Using [Monad] here leads to a universe inconsistency!? *)
Definition tmInferInstanceQ
    (debug : bool) (rs : option reductionStrategy) (q_constraint : term)
  : TM term :=
  constraint <- tmUnquoteTyped Type q_constraint ;;
  when debug (tmPrint constraint) ;;
  oinst <- tmInferInstance rs constraint ;;
  when debug (tmPrint oinst) ;;
  match oinst with
  | None =>
    tmPrint ("Ceres: Searching for", constraint) ;;
    tmFail "Ceres: Instance not found"
  | Some inst => tmQuote inst
  end.

Fixpoint q_list_of_list_q (ty : term) (ts : list term) : term :=
  match ts with
  | [] => mkApp q_nil ty
  | t :: ts => mkApps q_cons [ty ; t ; q_list_of_list_q ty ts]
  end. 

Fixpoint is_recursive_ctor_typen (n : nat) (t : term) : bool :=
  match t with
  | tProd x tx tf =>
    negb (closedn n tx) || is_recursive_ctor_typen (S n) tf
  | _ => false
  end.

Definition is_recursive_ctor_type : term -> bool :=
  is_recursive_ctor_typen 0.

Definition is_recursive (tyDef : mutual_inductive_body) : bool :=
  existsb (fun body =>
      existsb (fun ctor => is_recursive_ctor_type (snd (fst ctor))) (ind_ctors body)
    )%bool (ind_bodies tyDef).