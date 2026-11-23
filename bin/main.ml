(* Drafted with AI assistance (Claude Code); the PR says how it was checked. *)

open Types
module Battle = Combat.Make (Status) (Enemy_ai)

let sprintf = Printf.sprintf

(* Which screen the player is on, carrying what that screen needs. Combat
   state lives only inside [In_fight]; the run state alongside it is still the
   one from before the fight, until [Run.after_combat] replaces it. *)
type state =
  | At_title
  | At_map of run_state
  | In_fight of run_state * Battle.t
  | At_reward of run_state
  | Run_over

let screen_of = function
  | At_title -> Ui.Title
  | At_map _ -> Ui.Map
  | In_fight _ -> Ui.Combat
  | At_reward _ -> Ui.Reward
  | Run_over -> Ui.Game_over

let find_card c id = List.find_opt (fun d -> d.card_id = id) c.content_cards
let find_enemy c id = List.find_opt (fun e -> e.enemy_id = id) c.content_enemies

(* IDs are checked against the content at startup (starter deck) or come from
   the validated reward pool, so [filter_map] drops nothing in practice. *)
let cards_of c ids = List.filter_map (find_card c) ids
let one_to k = if k = 1 then "1" else sprintf "1 to %d" k
let reward_ids r = match r.run_phase with Reward_pending ids -> ids | _ -> []
let blocks parts = String.concat "\n\n" (List.filter (fun s -> s <> "") parts)

(* Each node gets its own random stream from the seed and the encounter
   counter, so replaying a seed (or reloading a save, once saves exist)
   reproduces the same shuffles, intents and reward offers. The trailing tag
   keeps the combat and reward streams independent. *)
let node_rng r tag =
  Random.State.make [| r.run_seed; r.run_next_encounter; tag |]

let show_map c r =
  match Run.available_nodes r with
  | [] -> (Run_over, Ui.render_run_over r)
  | choices -> (At_map r, Ui.render_map c r choices)

let start_run c seed =
  let seed =
    match seed with
    | Some s -> s
    | None -> Random.State.bits (Random.State.make_self_init ())
  in
  let st, text = show_map c (Run.new_run ~seed) in
  (st, blocks [ sprintf "Starting a new run (seed %d)." seed; text ])

let start_fight c r enemy_id =
  match find_enemy c enemy_id with
  | None -> (Run_over, sprintf "The map names an unknown enemy \"%s\"." enemy_id)
  | Some enemy -> (
      match
        Battle.init (node_rng r 0) ~deck:(cards_of c r.run_deck) ~hp:r.run_hp
          ~max_hp:r.run_max_hp [ enemy ]
      with
      | Error e -> (Run_over, "Could not start the fight: " ^ e)
      | Ok f ->
          ( In_fight (r, f),
            blocks
              [
                sprintf "%s blocks your path!" enemy.enemy_name;
                Ui.render_combat (Battle.view f);
              ] ))

let enter_node c r n =
  let choices = Run.available_nodes r in
  if n < 1 || n > List.length choices then
    ( At_map r,
      sprintf "There is no choice %d; choose from %s." n
        (one_to (List.length choices)) )
  else
    match Run.enter_node r (List.nth choices (n - 1)).node_id with
    | Error e -> (At_map r, e)
    | Ok r' -> (
        match r'.run_phase with
        | Fighting enemy_id -> start_fight c r' enemy_id
        | _ ->
            let st, text = show_map c r' in
            ( st,
              blocks
                [
                  sprintf "You rest and recover %d HP." (r'.run_hp - r.run_hp);
                  text;
                ] ))

let finish_fight c r res =
  let offer =
    if res.res_won then
      Rewards.generate (node_rng r 1) (cards_of c c.content_reward_pool)
      |> List.map (fun d -> d.card_id)
    else []
  in
  let headline = Ui.render_result res in
  match Run.after_combat r res ~reward_ids:offer with
  | Error e -> (Run_over, blocks [ headline; e ])
  | Ok r -> (
      match r.run_phase with
      | Won | Lost -> (Run_over, blocks [ headline; Ui.render_run_over r ])
      | Reward_pending (_ :: _ as ids) ->
          (At_reward r, blocks [ headline; Ui.render_rewards (cards_of c ids) ])
      | Reward_pending [] | On_map | Fighting _ ->
          (* An empty reward pool leaves nothing to choose, and
             [Run.choose_reward] would reject every choice, so skip straight
             back to the map. *)
          let st, text = show_map c { r with run_phase = On_map } in
          (st, blocks [ headline; text ]))

let continue_fight c r f prefix =
  match Battle.result f with
  | None ->
      (In_fight (r, f), blocks [ prefix; Ui.render_combat (Battle.view f) ])
  | Some res ->
      let st, text = finish_fight c r res in
      (st, blocks [ prefix; text ])

let play c r f ~card ~target =
  let name =
    match List.assoc_opt card (Battle.view f).cv_hand with
    | Some d -> d.card_name
    | None -> "the card"
  in
  match Battle.play_card f ~hand_index:card ~target_index:target with
  | Error e -> (In_fight (r, f), e)
  | Ok f' -> continue_fight c r f' (sprintf "You play %s." name)

let end_turn c r f =
  match Battle.end_turn f with
  | Error e -> (In_fight (r, f), e)
  | Ok f' ->
      continue_fight c r f'
        (Ui.render_enemy_turn ~before:(Battle.view f) ~after:(Battle.view f'))

let choose_reward c r n =
  let ids = reward_ids r in
  match Run.choose_reward r n with
  | Error _ ->
      ( At_reward r,
        sprintf "There is no reward %d; choose from %s." n
          (one_to (List.length ids)) )
  | Ok r' ->
      let added =
        match find_card c (List.nth ids (n - 1)) with
        | Some d -> d.card_name
        | None -> List.nth ids (n - 1)
      in
      let st, text = show_map c r' in
      (st, blocks [ sprintf "%s was added to your deck." added; text ])

(* [Quit] never reaches here: [loop] handles it before calling [step]. *)
let step c state cmd =
  match (state, cmd) with
  | _, Help -> (state, Ui.help (screen_of state))
  | (At_title | Run_over), New seed -> start_run c seed
  | (At_title | Run_over), Load _ ->
      (state, "Saving and loading are not available yet.")
  | At_map r, Choose n -> enter_node c r n
  | (At_map r | At_reward r), Show_deck ->
      (state, Ui.render_deck (cards_of c r.run_deck))
  | In_fight (r, f), Play (card, target) -> play c r f ~card ~target
  | In_fight (r, f), End_turn -> end_turn c r f
  | In_fight (_, f), Show_deck -> (state, Ui.render_deck (Battle.fight_cards f))
  | At_reward r, Choose n -> choose_reward c r n
  | _, cmd -> (state, Ui.not_available (screen_of state) cmd)

let rec loop c state =
  print_string "\n> ";
  flush stdout;
  match In_channel.input_line stdin with
  | None -> print_endline "\nGoodbye."
  | Some line -> (
      match Ui.parse line with
      | Ok Quit -> print_endline "Goodbye."
      | Error msg ->
          print_endline msg;
          loop c state
      | Ok cmd ->
          let state, text = step c state cmd in
          print_endline text;
          loop c state)

let node_enemy n =
  match n.node_kind with
  | Fight id | Elite id | Boss id -> Some id
  | Rest -> None

let load_content dir =
  let ( let* ) = Result.bind in
  let* c = Loader.load dir in
  let* () = Validate.content c in
  let starter = Run.new_run ~seed:0 in
  let* () = Validate.card_ids_known c starter.run_deck in
  let* () =
    Validate.enemy_ids_known c (List.filter_map node_enemy starter.run_map)
  in
  Ok c

let () =
  let dir = if Array.length Sys.argv > 1 then Sys.argv.(1) else "data" in
  match load_content dir with
  | Error msgs ->
      prerr_endline (sprintf "Could not load the game content from %s:" dir);
      List.iter (fun m -> prerr_endline ("  " ^ m)) msgs;
      prerr_endline
        "Run the game from the repository root, or pass the data folder: dune \
         exec bin/main.exe -- <dir>";
      exit 1
  | Ok c ->
      print_endline Ui.title;
      loop c At_title
