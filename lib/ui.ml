(* Drafted with AI assistance (Claude Code); the PR says how it was checked. *)

open Types

type screen = Title | Map | Combat | Reward | Game_over

let sprintf = Printf.sprintf

(* ---------- Input ---------- *)

let is_space c = c = ' ' || c = '\t' || c = '\r' || c = '\n'

let words line =
  String.map (fun c -> if is_space c then ' ' else c) line
  |> String.split_on_char ' '
  |> List.filter (fun w -> w <> "")

(* Everything after the first word, so a file name keeps its case and any
   inner spaces. *)
let after_first_word line =
  let s = String.trim line in
  let rec first_space i =
    if i >= String.length s || is_space s.[i] then i else first_space (i + 1)
  in
  let i = first_space 0 in
  String.trim (String.sub s i (String.length s - i))

(* Digits only: int_of_string alone would also accept "-3", "0x1f" and
   "1_000", none of which a player means as a menu number. *)
let number s =
  if s <> "" && String.for_all (fun c -> c >= '0' && c <= '9') s then
    int_of_string_opt s
  else None

let play_usage = "Type play <card> [enemy], e.g. play 1 or play 1 2."
let new_usage = "Type new or new <seed>, e.g. new 42."

let numeric ~what ~usage s =
  match number s with
  | Some n -> Ok n
  | None -> Error (sprintf "\"%s\" is not %s. %s" s what usage)

let parse line =
  let ( let* ) = Result.bind in
  match words line with
  | [] -> Error "Type a command, or help to see what you can do."
  | verb :: args -> (
      match (String.lowercase_ascii verb, args) with
      | "new", [] -> Ok (New None)
      | "new", [ s ] ->
          let* seed = numeric ~what:"a seed" ~usage:new_usage s in
          Ok (New (Some seed))
      | "new", _ -> Error ("new takes at most one seed. " ^ new_usage)
      | "load", [] -> Error "load needs a file name, e.g. load save.json."
      | "load", _ -> Ok (Load (after_first_word line))
      | "play", [] -> Error ("play needs a card number. " ^ play_usage)
      | "play", [ c ] ->
          let* c = numeric ~what:"a card number" ~usage:play_usage c in
          Ok (Play (c, None))
      | "play", [ c; e ] ->
          let* c = numeric ~what:"a card number" ~usage:play_usage c in
          let* e = numeric ~what:"an enemy number" ~usage:play_usage e in
          Ok (Play (c, Some e))
      | "play", _ -> Error ("play takes at most two numbers. " ^ play_usage)
      | "choose", [ n ] ->
          let* n =
            numeric ~what:"a choice number"
              ~usage:"Type choose <n>, e.g. choose 1." n
          in
          Ok (Choose n)
      | "choose", _ -> Error "choose needs one number, e.g. choose 1."
      | "end", [] -> Ok End_turn
      | "deck", [] -> Ok Show_deck
      | "help", [] -> Ok Help
      | "quit", [] -> Ok Quit
      | (("end" | "deck" | "help" | "quit") as v), _ ->
          Error (sprintf "%s does not take anything after it. Type %s." v v)
      | _ ->
          Error
            (sprintf "Unknown command \"%s\". Type help to see the commands."
               verb))

let command_name = function
  | New _ -> "new"
  | Load _ -> "load"
  | Play _ -> "play"
  | End_turn -> "end"
  | Choose _ -> "choose"
  | Show_deck -> "deck"
  | Help -> "help"
  | Quit -> "quit"

let where = function
  | Title -> "before a run starts"
  | Map -> "on the map"
  | Combat -> "during a fight"
  | Reward -> "while choosing a reward"
  | Game_over -> "now that the run is over"

let not_available screen cmd =
  sprintf "You can't use %s %s. Type help to see what you can do here."
    (command_name cmd) (where screen)

(* ---------- Output helpers ---------- *)

let plural n word =
  if n = 1 then sprintf "%d %s" n word else sprintf "%d %ss" n word

let indent lines = List.map (fun l -> "  " ^ l) lines

let status_name = function
  | Strength -> "Strength"
  | Weak -> "Weak"
  | Vulnerable -> "Vulnerable"
  | Poison -> "Poison"

let render_statuses m =
  [ Strength; Weak; Vulnerable; Poison ]
  |> List.filter_map (fun s ->
         Option.map
           (fun n -> sprintf "%s %d" (status_name s) n)
           (List.assoc_opt s m))
  |> function
  | [] -> "none"
  | parts -> String.concat ", " parts

let statuses_suffix m =
  if m = [] then "" else "  Statuses: " ^ render_statuses m

let render_card n c =
  sprintf "%d. %s (%d energy): %s" n c.card_name c.card_cost c.card_description

(* ---------- Screens ---------- *)

let title =
  String.concat "\n"
    [
      "SLAY THE CAML";
      "A terminal deck-builder. Read the enemy's intent, play your cards, grow \
       your deck.";
      "";
      "Type new to start a run (or new <seed> to replay one), help for \
       commands, or quit to leave.";
    ]

let help_entries = function
  | Title | Game_over ->
      [ ("new [seed]", "Start a run, optionally with a fixed seed") ]
  | Map ->
      [
        ("choose <n>", "Travel to map choice n"); ("deck", "Show your run deck");
      ]
  | Combat ->
      [
        ( "play <card> [enemy]",
          "Play hand card <card>; add <enemy> if it hits one enemy" );
        ("end", "End your turn; enemies then do what their intent says");
        ("deck", "Show every card in this fight, sorted by name");
      ]
  | Reward ->
      [
        ("choose <n>", "Add reward card n to your deck");
        ("deck", "Show your run deck");
      ]

let help screen =
  let entries =
    help_entries screen
    @ [ ("help", "Show this list"); ("quit", "Leave the game") ]
  in
  String.concat "\n"
    (sprintf "Commands %s:" (where screen)
    :: indent
         (List.map (fun (cmd, what) -> sprintf "%-20s %s" cmd what) entries))

let render_enemy e =
  [
    sprintf "%d. %s  HP %d/%d  Block %d%s" e.ce_number e.ce_name e.ce_hp
      e.ce_max_hp e.ce_block
      (statuses_suffix e.ce_statuses);
    sprintf "   Intent: %s" e.ce_intent.intent_label;
  ]

let render_combat v =
  let enemies =
    match v.cv_enemies with
    | [] -> [ "  none" ]
    | es -> indent (List.concat_map render_enemy es)
  in
  let hand =
    match v.cv_hand with
    | [] -> [ "  (empty)" ]
    | cards -> indent (List.map (fun (n, c) -> render_card n c) cards)
  in
  String.concat "\n"
    ([ sprintf "== Turn %d ==" v.cv_turn; ""; "Enemies:" ]
    @ enemies
    @ [
        "";
        sprintf "You  HP %d/%d  Block %d  Energy %d/%d%s" v.cv_player_hp
          v.cv_player_max_hp v.cv_player_block v.cv_energy v.cv_max_energy
          (statuses_suffix v.cv_player_statuses);
        "";
        "Hand:";
      ]
    @ hand
    @ [
        sprintf "Draw pile %d  Discard pile %d" v.cv_draw_count
          v.cv_discard_count;
        "";
        "Type play <card> [enemy], end, or help.";
      ])

let render_enemy_turn ~before ~after =
  let acted =
    List.map
      (fun e -> sprintf "%s: %s" e.ce_name e.ce_intent.intent_label)
      before.cv_enemies
  in
  let lost = before.cv_player_hp - after.cv_player_hp in
  let hp_line =
    if lost > 0 then sprintf "You lost %d HP." lost else "You lost no HP."
  in
  String.concat "\n" (("Enemy turn:" :: indent acted) @ [ hp_line ])

let render_result r =
  if r.res_won then
    sprintf "Victory! You have %d HP left and earned %d gold." r.res_hp_left
      r.res_gold
  else "Defeat. You have fallen."

let render_run_over r =
  let summary =
    match r.run_phase with
    | Won -> "You defeated the boss and won the run!"
    | Lost -> "Your run is over."
    | On_map | Fighting _ | Reward_pending _ ->
        "The path ends here: you have cleared every node on this map."
  in
  String.concat "\n"
    [
      summary;
      sprintf "Final: HP %d/%d  Gold %d  Deck %s" r.run_hp r.run_max_hp
        r.run_gold
        (plural (List.length r.run_deck) "card");
      "";
      "Type new to start another run, or quit.";
    ]

let enemy_name content id =
  match List.find_opt (fun e -> e.enemy_id = id) content.content_enemies with
  | Some e -> e.enemy_name
  | None -> id

let node_label content node =
  match node.node_kind with
  | Fight id -> "Fight: " ^ enemy_name content id
  | Elite id -> "Elite: " ^ enemy_name content id
  | Rest -> "Rest"
  | Boss id -> "Boss: " ^ enemy_name content id

let render_map content r choices =
  let marker node =
    if r.run_current_node = Some node.node_id then " (you are here)"
    else if List.mem node.node_id r.run_visited then " (visited)"
    else ""
  in
  let rows =
    List.sort_uniq compare (List.map (fun n -> n.node_row) r.run_map)
    |> List.map (fun row ->
           r.run_map
           |> List.filter (fun n -> n.node_row = row)
           |> List.map (fun n -> node_label content n ^ marker n)
           |> String.concat " | " |> sprintf "Row %d: %s" row)
  in
  let choice_lines =
    match choices with
    | [] -> [ "There is nowhere left to go." ]
    | _ ->
        "Where to next?"
        :: indent
             (List.mapi
                (fun i n ->
                  sprintf "%d. %s (row %d)" (i + 1) (node_label content n)
                    n.node_row)
                choices)
        @ [ "Type choose <n>." ]
  in
  String.concat "\n"
    ([
       "== Map ==";
       sprintf "HP %d/%d  Gold %d  Deck %s" r.run_hp r.run_max_hp r.run_gold
         (plural (List.length r.run_deck) "card");
       "";
     ]
    @ indent rows @ [ "" ] @ choice_lines)

let render_rewards cards =
  String.concat "\n"
    ("Choose a card to add to your deck:"
     :: indent (List.mapi (fun i c -> render_card (i + 1) c) cards)
    @ [ "Type choose <n>." ])

let render_deck cards =
  let groups =
    List.fold_left
      (fun acc c ->
        if List.mem_assoc c.card_id acc then
          List.map
            (fun (id, (d, n)) ->
              if id = c.card_id then (id, (d, n + 1)) else (id, (d, n)))
            acc
        else acc @ [ (c.card_id, (c, 1)) ])
      [] cards
  in
  let line (_, (c, n)) =
    sprintf "%dx %s (%d energy): %s" n c.card_name c.card_cost
      c.card_description
  in
  String.concat "\n"
    (sprintf "Deck (%s):" (plural (List.length cards) "card")
    :: indent (List.map line groups))
