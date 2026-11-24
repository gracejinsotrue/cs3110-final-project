(* AI acknowledgement: written with AI assistance (Claude Code) from the team
   plan; owner Nick Lennon (ncl46). Checked with test/combat_test.ml, planted
   bugs that the tests had to catch, and seeded runs on the real data/ files.
   PRs #9 and #11 give the details. *)

open Types

let ( let* ) = Result.bind

module Make (S : Sigs.STATUS) (AI : Sigs.ENEMY_AI) = struct
  (** Energy at the start of each player turn. *)
  let max_energy = 3

  (** Cards drawn at the start of each player turn. *)
  let hand_size = 5

  type foe = {
    foe_def : enemy_def;  (** Its definition. *)
    foe_hp : int;  (** Current HP, 0 when dead. *)
    foe_block : int;  (** Current block. *)
    foe_statuses : status_map;  (** Current statuses. *)
    foe_turns : int;  (** Turns it has taken; becomes [ev_turn]. *)
    foe_intent : intent;  (** The intent it shows and will run next. *)
  }
  (** One enemy's live state. Dead enemies stay in the list (with [foe_hp = 0])
      so the display order never changes. *)

  type t = {
    cb_rng : Random.State.t;  (** Shuffles and random intents. *)
    cb_hp : int;  (** Player HP. *)
    cb_max_hp : int;  (** Player max HP. *)
    cb_block : int;  (** Player block. *)
    cb_statuses : status_map;  (** Player statuses. *)
    cb_energy : int;  (** Energy left this turn. *)
    cb_turn : int;  (** Player turn number, from 1. *)
    cb_hand : card_def list;  (** The hand. *)
    cb_draw : card_def list;  (** The draw pile. *)
    cb_discard : card_def list;  (** The discard pile; order unused. *)
    cb_foes : foe list;  (** Every enemy, living or dead, in display order. *)
    cb_result : combat_result option;  (** [Some _] once the fight is over. *)
  }
  (** The whole fight. Lists of cards are ordered: [cb_hand] in hand order,
      [cb_draw] top card first. [cb_rng] is private to this fight and is copied
      before each operation that uses it, so a [t] never changes. *)

  (* ---------- Small helpers ---------- *)

  let wait = { intent_label = "Wait"; intent_actions = [] }
  let alive f = f.foe_hp > 0
  let over t = Option.is_some t.cb_result

  (** [map_in_order f l] is [List.map f l], applying [f] front to back. The
      order matters because [f] may draw from a random state. *)
  let map_in_order f l =
    List.rev (List.fold_left (fun acc x -> f x :: acc) [] l)

  (** [fresh t] is [t] with its own copy of the random state, so the operation
      that follows cannot change the caller's [t]. *)
  let fresh t = { t with cb_rng = Random.State.copy t.cb_rng }

  (** Fisher-Yates shuffle drawing from [rng]. *)
  let shuffle rng l =
    let a = Array.of_list l in
    for i = Array.length a - 1 downto 1 do
      let j = Random.State.int rng (i + 1) in
      let tmp = a.(i) in
      a.(i) <- a.(j);
      a.(j) <- tmp
    done;
    Array.to_list a

  (** [remove_nth i l] is [l] without its element at 0-based index [i]. *)
  let remove_nth i l = List.filteri (fun j _ -> j <> i) l

  (** [update_foe i g t] replaces the foe at 0-based index [i] with [g foe]. *)
  let update_foe i g t =
    {
      t with
      cb_foes = List.mapi (fun j f -> if j = i then g f else f) t.cb_foes;
    }

  let foe i t = List.nth t.cb_foes i

  (** 0-based indices into [cb_foes] of the living foes, in display order. The
      player's enemy number [n] means element [n - 1] of this list. *)
  let living_indices t =
    t.cb_foes
    |> List.mapi (fun i f -> (i, f))
    |> List.filter (fun (_, f) -> alive f)
    |> List.map fst

  let enemy_view f =
    {
      ev_hp = f.foe_hp;
      ev_max_hp = f.foe_def.enemy_max_hp;
      ev_block = f.foe_block;
      ev_turn = f.foe_turns;
      ev_statuses = f.foe_statuses;
    }

  (* ---------- End of the fight ---------- *)

  (** [settle t] records the result if the player or every enemy has just
      reached 0 HP. Once a result is recorded it never changes. *)
  let settle t =
    if over t then t
    else if t.cb_hp <= 0 then
      {
        t with
        cb_hp = 0;
        cb_result = Some { res_won = false; res_hp_left = 0; res_gold = 0 };
      }
    else if not (List.exists alive t.cb_foes) then
      let gold =
        List.fold_left (fun acc f -> acc + f.foe_def.enemy_gold) 0 t.cb_foes
      in
      {
        t with
        cb_result =
          Some { res_won = true; res_hp_left = t.cb_hp; res_gold = gold };
      }
    else t

  (* ---------- Damage ---------- *)

  (** [hit ~attacker ~defender base ~block ~hp] is the defender's [(block, hp)]
      after one hit of [base] damage. *)
  let hit ~attacker ~defender base ~block ~hp =
    let dmg = base |> S.outgoing attacker |> S.incoming defender |> max 0 in
    let absorbed = min block dmg in
    (block - absorbed, max 0 (hp - (dmg - absorbed)))

  (** The player hits the foe at index [i] for [base], if it is alive. *)
  let player_hits base i t =
    update_foe i
      (fun f ->
        if not (alive f) then f
        else
          let block, hp =
            hit ~attacker:t.cb_statuses ~defender:f.foe_statuses base
              ~block:f.foe_block ~hp:f.foe_hp
          in
          { f with foe_block = block; foe_hp = hp })
      t

  (* ---------- Drawing ---------- *)

  (** [draw n t] moves up to [n] cards from the draw pile to the end of the
      hand, shuffling the discard pile into a new draw pile when the draw pile
      runs out. Stops early if both piles are empty. *)
  let rec draw n t =
    if n <= 0 then t
    else
      match (t.cb_draw, t.cb_discard) with
      | c :: rest, _ ->
          draw (n - 1) { t with cb_hand = t.cb_hand @ [ c ]; cb_draw = rest }
      | [], [] -> t
      | [], discard ->
          draw n { t with cb_draw = shuffle t.cb_rng discard; cb_discard = [] }

  (** [start_player_turn turn t] clears block, refills energy and draws a new
      hand for player turn [turn]. *)
  let start_player_turn turn t =
    draw hand_size
      { t with cb_block = 0; cb_energy = max_energy; cb_turn = turn }

  (* ---------- Cards ---------- *)

  (** [targets tgt sel t] is the foe indices an effect with target [tgt]
      reaches. [sel] is the selected foe's index, if any. *)
  let targets tgt sel t =
    match (tgt, sel) with
    | Selected_enemy, Some i -> [ i ]
    | Selected_enemy, None | Self, _ -> []
    | All_enemies, _ -> living_indices t

  (** Runs one card effect. A hit on a dead foe does nothing. *)
  let apply_effect sel t = function
    | Deal (Self, _) -> t (* invalid content; Validate rejects it *)
    | Deal (tgt, n) ->
        List.fold_left (fun t i -> player_hits n i t) t (targets tgt sel t)
    | Gain_block n -> { t with cb_block = t.cb_block + max 0 n }
    | Apply_status (Self, s, n) ->
        { t with cb_statuses = S.apply s n t.cb_statuses }
    | Apply_status (tgt, s, n) ->
        List.fold_left
          (fun t i ->
            update_foe i
              (fun f ->
                if alive f then
                  { f with foe_statuses = S.apply s n f.foe_statuses }
                else f)
              t)
          t (targets tgt sel t)
    | Draw n -> draw n t
    | Gain_energy n -> { t with cb_energy = t.cb_energy + max 0 n }

  (** Runs effects in order, stopping as soon as the fight ends. *)
  let rec run_effects sel t = function
    | [] -> t
    | e :: rest ->
        let t = settle (apply_effect sel t e) in
        if over t then t else run_effects sel t rest

  let needs_target card =
    List.exists
      (function
        | Deal (Selected_enemy, _) | Apply_status (Selected_enemy, _, _) -> true
        | _ -> false)
      card.card_effects

  (** The hand card with 1-based number [n]. *)
  let hand_card t n =
    let k = List.length t.cb_hand in
    if k = 0 then Error "Your hand is empty. Type end to end your turn."
    else if n < 1 || n > k then
      let hint =
        if k = 1 then "your only card is 1"
        else Printf.sprintf "choose a card from 1 to %d" k
      in
      Error (Printf.sprintf "There is no card %d in your hand; %s." n hint)
    else Ok (List.nth t.cb_hand (n - 1))

  let check_cost t card =
    if card.card_cost <= t.cb_energy then Ok ()
    else
      Error
        (Printf.sprintf "%s costs %d energy, but you have %d." card.card_name
           card.card_cost t.cb_energy)

  (** The foe index named by the player's target number, or [None] for a card
      that takes no target. *)
  let resolve_target t card hand_index target_index =
    match (needs_target card, target_index) with
    | false, None -> Ok None
    | false, Some _ ->
        Error
          (Printf.sprintf "%s does not take an enemy number. Type: play %d"
             card.card_name hand_index)
    | true, None ->
        Error
          (Printf.sprintf "%s needs an enemy number, e.g. play %d 1."
             card.card_name hand_index)
    | true, Some n ->
        let living = living_indices t in
        let k = List.length living in
        if n < 1 || n > k then
          let hint =
            if k = 1 then "the only enemy is 1"
            else Printf.sprintf "choose an enemy from 1 to %d" k
          in
          Error (Printf.sprintf "There is no enemy %d; %s." n hint)
        else Ok (Some (List.nth living (n - 1)))

  (* ---------- Enemy round ---------- *)

  (** Foe [i] performs one action. *)
  let foe_action i t = function
    | Attack n ->
        let f = foe i t in
        let block, hp =
          hit ~attacker:f.foe_statuses ~defender:t.cb_statuses n
            ~block:t.cb_block ~hp:t.cb_hp
        in
        { t with cb_block = block; cb_hp = hp }
    | Defend n ->
        update_foe i (fun f -> { f with foe_block = f.foe_block + max 0 n }) t
    | Inflict (s, n) -> { t with cb_statuses = S.apply s n t.cb_statuses }
    | Buff (s, n) ->
        update_foe i
          (fun f -> { f with foe_statuses = S.apply s n f.foe_statuses })
          t

  (** Foe [i] ticks its statuses and takes its poison damage. *)
  let foe_tick i t =
    update_foe i
      (fun f ->
        let statuses, poison = S.tick f.foe_statuses in
        {
          f with
          foe_statuses = statuses;
          foe_hp = max 0 (f.foe_hp - poison);
          foe_turns = f.foe_turns + 1;
        })
      t

  (** Foe [i]'s whole turn: clear block, run its shown intent, tick. *)
  let foe_turn i t =
    if over t || not (alive (foe i t)) then t
    else
      let t = update_foe i (fun f -> { f with foe_block = 0 }) t in
      let rec act t = function
        | [] -> t
        | a :: rest ->
            let t = settle (foe_action i t a) in
            if over t then t else act t rest
      in
      let t = act t (foe i t).foe_intent.intent_actions in
      if over t then t else settle (foe_tick i t)

  let enemy_round t =
    List.fold_left
      (fun t i -> foe_turn i t)
      t
      (List.init (List.length t.cb_foes) Fun.id)

  (** Every living foe picks the intent it will show next. *)
  let choose_intents t =
    {
      t with
      cb_foes =
        map_in_order
          (fun f ->
            if alive f then
              {
                f with
                foe_intent = AI.next_intent t.cb_rng f.foe_def (enemy_view f);
              }
            else f)
          t.cb_foes;
    }

  (* ---------- Public interface ---------- *)

  let init rng ~deck ~hp ~max_hp enemies =
    if enemies = [] then Error "A fight needs at least one enemy."
    else if max_hp <= 0 then
      Error (Printf.sprintf "Max HP must be positive, but it is %d." max_hp)
    else if hp < 1 || hp > max_hp then
      Error
        (Printf.sprintf "Starting HP must be from 1 to %d, but it is %d." max_hp
           hp)
    else
      let draw_pile = shuffle rng deck in
      let foes =
        map_in_order
          (fun d ->
            let f =
              {
                foe_def = d;
                foe_hp = d.enemy_max_hp;
                foe_block = 0;
                foe_statuses = [];
                foe_turns = 0;
                foe_intent = wait;
              }
            in
            { f with foe_intent = AI.next_intent rng d (enemy_view f) })
          enemies
      in
      let t =
        {
          cb_rng = Random.State.make [| Random.State.bits rng |];
          cb_hp = hp;
          cb_max_hp = max_hp;
          cb_block = 0;
          cb_statuses = [];
          cb_energy = 0;
          cb_turn = 0;
          cb_hand = [];
          cb_draw = draw_pile;
          cb_discard = [];
          cb_foes = foes;
          cb_result = None;
        }
      in
      Ok (settle (start_player_turn 1 t))

  let play_card t ~hand_index ~target_index =
    let* () = if over t then Error "The fight is over." else Ok () in
    let* card = hand_card t hand_index in
    let* sel = resolve_target t card hand_index target_index in
    let* () = check_cost t card in
    let t = fresh t in
    let t =
      {
        t with
        cb_hand = remove_nth (hand_index - 1) t.cb_hand;
        cb_energy = t.cb_energy - card.card_cost;
      }
    in
    let t = run_effects sel t card.card_effects in
    Ok { t with cb_discard = card :: t.cb_discard }

  let end_turn t =
    if over t then Error "The fight is over."
    else
      let t = fresh t in
      let t = { t with cb_discard = t.cb_hand @ t.cb_discard; cb_hand = [] } in
      let statuses, poison = S.tick t.cb_statuses in
      let t =
        settle
          { t with cb_statuses = statuses; cb_hp = max 0 (t.cb_hp - poison) }
      in
      let t = enemy_round t in
      if over t then Ok t
      else Ok (t |> choose_intents |> start_player_turn (t.cb_turn + 1))

  let view t =
    {
      cv_player_hp = t.cb_hp;
      cv_player_max_hp = t.cb_max_hp;
      cv_player_block = t.cb_block;
      cv_player_statuses = t.cb_statuses;
      cv_energy = t.cb_energy;
      cv_max_energy = max_energy;
      cv_turn = t.cb_turn;
      cv_hand = List.mapi (fun i c -> (i + 1, c)) t.cb_hand;
      cv_draw_count = List.length t.cb_draw;
      cv_discard_count = List.length t.cb_discard;
      cv_enemies =
        t.cb_foes |> List.filter alive
        |> List.mapi (fun i f ->
            {
              ce_number = i + 1;
              ce_name = f.foe_def.enemy_name;
              ce_hp = f.foe_hp;
              ce_max_hp = f.foe_def.enemy_max_hp;
              ce_block = f.foe_block;
              ce_statuses = f.foe_statuses;
              ce_intent = f.foe_intent;
            });
    }

  let result t = t.cb_result

  let fight_cards t =
    t.cb_hand @ t.cb_draw @ t.cb_discard
    |> List.stable_sort (fun a b ->
        compare (a.card_name, a.card_id) (b.card_name, b.card_id))
end
