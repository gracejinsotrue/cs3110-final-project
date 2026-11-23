(* Drafted with AI assistance (Claude Code); the PR says how it was checked. *)

(** Tests for [Ui]: command parsing and the text of each screen. Rendering tests
    build views by hand and check for the pieces a player relies on (numbers,
    names, intents) rather than exact layout, so spacing can change without
    breaking them. *)

open OUnit2
open Types

let contains s sub =
  let n = String.length s and m = String.length sub in
  let rec go i = i + m <= n && (String.sub s i m = sub || go (i + 1)) in
  go 0

let assert_contains s sub =
  assert_bool (Printf.sprintf "expected %S in:\n%s" sub s) (contains s sub)

let assert_lacks s sub =
  assert_bool
    (Printf.sprintf "did not expect %S in:\n%s" sub s)
    (not (contains s sub))

let show_command = function
  | New None -> "New None"
  | New (Some n) -> Printf.sprintf "New (Some %d)" n
  | Load f -> Printf.sprintf "Load %S" f
  | Play (c, None) -> Printf.sprintf "Play (%d, None)" c
  | Play (c, Some e) -> Printf.sprintf "Play (%d, Some %d)" c e
  | End_turn -> "End_turn"
  | Choose n -> Printf.sprintf "Choose %d" n
  | Show_deck -> "Show_deck"
  | Help -> "Help"
  | Quit -> "Quit"

let show_parse = function
  | Ok c -> "Ok (" ^ show_command c ^ ")"
  | Error e -> Printf.sprintf "Error %S" e

let parses input expected =
  input >:: fun _ ->
  assert_equal ~printer:show_parse (Ok expected) (Ui.parse input)

(* The message should mention [hint] so the player knows what to type. *)
let rejects ?(hint = "") input =
  "rejects " ^ String.escaped input >:: fun _ ->
  match Ui.parse input with
  | Ok c -> assert_failure ("parsed as " ^ show_command c)
  | Error msg ->
      assert_bool "error message is empty" (msg <> "");
      if hint <> "" then assert_contains msg hint

let parse_tests =
  "parse"
  >::: [
         parses "play 2 1" (Play (2, Some 1));
         parses "play 2" (Play (2, None));
         parses "  PLAY   2\t1  " (Play (2, Some 1));
         parses "play 0" (Play (0, None));
         parses "play 007 2" (Play (7, Some 2));
         parses "end" End_turn;
         parses "End" End_turn;
         parses "choose 3" (Choose 3);
         parses "new" (New None);
         parses "new 42" (New (Some 42));
         parses "load Saves/My Run.json" (Load "Saves/My Run.json");
         parses "deck" Show_deck;
         parses "help" Help;
         parses "QUIT" Quit;
         rejects ~hint:"play <card>" "play x";
         rejects ~hint:"play <card>" "play";
         rejects ~hint:"enemy" "play 1 x";
         rejects ~hint:"at most two" "play 1 2 3";
         rejects "play -1";
         rejects "play +1";
         rejects "play 0x1f";
         rejects "play 99999999999999999999999999";
         rejects ~hint:"new <seed>" "new x";
         rejects "new 1 2";
         rejects ~hint:"choose 1" "choose";
         rejects "choose two";
         rejects ~hint:"load save.json" "load";
         rejects ~hint:"Type end" "end 1";
         rejects "deck all";
         rejects "quit now";
         rejects ~hint:"help" "";
         rejects ~hint:"help" "   ";
         rejects ~hint:"\"dance\"" "dance";
       ]

let command_tests =
  "command names"
  >::: [
         ( "every command has the word the player types" >:: fun _ ->
           List.iter
             (fun (cmd, word) ->
               assert_equal ~printer:Fun.id word (Ui.command_name cmd))
             [
               (New None, "new");
               (Load "f", "load");
               (Play (1, None), "play");
               (End_turn, "end");
               (Choose 1, "choose");
               (Show_deck, "deck");
               (Help, "help");
               (Quit, "quit");
             ] );
         ( "not_available names the command and points to help" >:: fun _ ->
           let msg = Ui.not_available Ui.Map (Play (1, None)) in
           assert_contains msg "play";
           assert_contains msg "help" );
       ]

let help_tests =
  let check screen ~has ~lacks =
    let text = Ui.help screen in
    List.iter (assert_contains text) has;
    List.iter (assert_lacks text) lacks
  in
  "help"
  >::: [
         ( "title" >:: fun _ ->
           check Ui.Title ~has:[ "new"; "help"; "quit" ]
             ~lacks:[ "play"; "choose" ] );
         ( "map" >:: fun _ ->
           check Ui.Map
             ~has:[ "choose"; "deck"; "quit" ]
             ~lacks:[ "play"; "new" ] );
         ( "combat" >:: fun _ ->
           check Ui.Combat
             ~has:[ "play <card> [enemy]"; "end"; "deck" ]
             ~lacks:[ "choose"; "new" ] );
         ( "reward" >:: fun _ ->
           check Ui.Reward ~has:[ "choose"; "deck" ] ~lacks:[ "play"; "new" ] );
         ( "game over" >:: fun _ ->
           check Ui.Game_over ~has:[ "new" ] ~lacks:[ "play" ] );
       ]

let card ?(cost = 1) id name desc effects =
  {
    card_id = id;
    card_name = name;
    card_cost = cost;
    card_description = desc;
    card_effects = effects;
  }

let strike =
  card "strike" "Strike" "Deal 6 to one enemy" [ Deal (Selected_enemy, 6) ]

let defend = card "defend" "Defend" "Gain 5 block" [ Gain_block 5 ]

let bash =
  card ~cost:2 "bash" "Bash" "Deal 8; apply 2 Vulnerable to one enemy"
    [ Deal (Selected_enemy, 8); Apply_status (Selected_enemy, Vulnerable, 2) ]

let intent label actions = { intent_label = label; intent_actions = actions }

let enemy_view ?(statuses = []) n name hp label =
  {
    ce_number = n;
    ce_name = name;
    ce_hp = hp;
    ce_max_hp = 30;
    ce_block = 3;
    ce_statuses = statuses;
    ce_intent = intent label [];
  }

let view =
  {
    cv_player_hp = 61;
    cv_player_max_hp = 80;
    cv_player_block = 4;
    cv_player_statuses = [ (Poison, 3); (Weak, 1) ];
    cv_energy = 2;
    cv_max_energy = 3;
    cv_turn = 4;
    cv_hand = [ (1, strike); (2, defend); (3, bash) ];
    cv_draw_count = 6;
    cv_discard_count = 2;
    cv_enemies =
      [
        enemy_view
          ~statuses:[ (Vulnerable, 2) ]
          1 "Training Slime" 22 "Attack 5";
        enemy_view 2 "Spore Beast" 30 "Defend 3";
      ];
  }

let render_tests =
  "render"
  >::: [
         ( "combat shows numbered hand cards" >:: fun _ ->
           let s = Ui.render_combat view in
           assert_contains s "1. Strike (1 energy): Deal 6 to one enemy";
           assert_contains s "2. Defend";
           assert_contains s "3. Bash (2 energy)" );
         ( "combat shows every enemy's number and intent" >:: fun _ ->
           let s = Ui.render_combat view in
           assert_contains s "1. Training Slime";
           assert_contains s "2. Spore Beast";
           assert_contains s "Intent: Attack 5";
           assert_contains s "Intent: Defend 3" );
         ( "combat shows the player's and enemies' numbers" >:: fun _ ->
           let s = Ui.render_combat view in
           List.iter (assert_contains s)
             [
               "Turn 4";
               "HP 61/80";
               "Block 4";
               "Energy 2/3";
               "HP 22/30";
               "Block 3";
               "Vulnerable 2";
               "Weak 1, Poison 3";
               "Draw pile 6";
               "Discard pile 2";
             ] );
         ( "combat with an empty hand says so" >:: fun _ ->
           assert_contains
             (Ui.render_combat { view with cv_hand = [] })
             "(empty)" );
         ( "statuses use a fixed order and say none when empty" >:: fun _ ->
           assert_equal ~printer:Fun.id "none" (Ui.render_statuses []);
           assert_equal ~printer:Fun.id "Strength 2, Vulnerable 1, Poison 4"
             (Ui.render_statuses
                [ (Poison, 4); (Vulnerable, 1); (Strength, 2) ]) );
         ( "card line" >:: fun _ ->
           assert_equal ~printer:Fun.id
             "2. Bash (2 energy): Deal 8; apply 2 Vulnerable to one enemy"
             (Ui.render_card 2 bash) );
         ( "enemy turn lists intents and HP lost" >:: fun _ ->
           let after = { view with cv_player_hp = 56 } in
           let s = Ui.render_enemy_turn ~before:view ~after in
           assert_contains s "Training Slime: Attack 5";
           assert_contains s "Spore Beast: Defend 3";
           assert_contains s "You lost 5 HP." );
         ( "enemy turn with no damage" >:: fun _ ->
           assert_contains
             (Ui.render_enemy_turn ~before:view ~after:view)
             "no HP" );
         ( "result" >:: fun _ ->
           let won =
             Ui.render_result { res_won = true; res_hp_left = 70; res_gold = 5 }
           in
           assert_contains won "Victory";
           assert_contains won "5 gold";
           assert_contains won "70 HP";
           assert_contains
             (Ui.render_result
                { res_won = false; res_hp_left = 0; res_gold = 0 })
             "Defeat" );
         ( "rewards are numbered from 1" >:: fun _ ->
           let s = Ui.render_rewards [ strike; bash ] in
           assert_contains s "1. Strike";
           assert_contains s "2. Bash";
           assert_contains s "choose <n>" );
         ( "deck groups copies in first-seen order" >:: fun _ ->
           let s = Ui.render_deck [ strike; defend; strike; bash; strike ] in
           assert_contains s "Deck (5 cards)";
           assert_contains s "3x Strike (1 energy)";
           assert_contains s "1x Defend";
           assert_contains s "1x Bash";
           let index sub =
             let rec go i =
               if String.sub s i (String.length sub) = sub then i else go (i + 1)
             in
             go 0
           in
           assert_bool "Strike before Defend before Bash"
             (index "Strike" < index "Defend" && index "Defend" < index "Bash")
         );
         ( "deck of one card is singular" >:: fun _ ->
           assert_contains (Ui.render_deck [ bash ]) "Deck (1 card)" );
       ]

let slime =
  {
    enemy_id = "training_slime";
    enemy_name = "Training Slime";
    enemy_max_hp = 30;
    enemy_gold = 5;
    enemy_behavior = Cycle [ intent "Attack 5" [ Attack 5 ] ];
  }

let content =
  {
    content_cards = [ strike; defend; bash ];
    content_enemies = [ slime ];
    content_reward_pool = [];
  }

let nodes =
  [
    {
      node_id = 1;
      node_kind = Fight "training_slime";
      node_row = 1;
      node_next = [ 2; 3 ];
    };
    { node_id = 2; node_kind = Rest; node_row = 2; node_next = [ 4 ] };
    {
      node_id = 3;
      node_kind = Elite "mystery";
      node_row = 2;
      node_next = [ 4 ];
    };
    {
      node_id = 4;
      node_kind = Boss "training_slime";
      node_row = 3;
      node_next = [];
    };
  ]

let run =
  {
    run_seed = 1;
    run_map = nodes;
    run_current_node = Some 1;
    run_visited = [ 1 ];
    run_deck = [ "strike"; "strike"; "defend" ];
    run_hp = 70;
    run_max_hp = 80;
    run_gold = 12;
    run_next_encounter = 1;
    run_phase = On_map;
  }

let map_tests =
  "map and run end"
  >::: [
         ( "map numbers the choices and names enemies" >:: fun _ ->
           let s =
             Ui.render_map content run [ List.nth nodes 1; List.nth nodes 2 ]
           in
           assert_contains s "1. Rest (row 2)";
           assert_contains s "2. Elite: mystery (row 2)";
           assert_contains s "Fight: Training Slime (you are here)";
           assert_contains s "Boss: Training Slime";
           assert_contains s "HP 70/80";
           assert_contains s "Gold 12";
           assert_contains s "Deck 3 cards" );
         ( "visited nodes are marked" >:: fun _ ->
           let r =
             { run with run_current_node = Some 2; run_visited = [ 1; 2 ] }
           in
           let s = Ui.render_map content r [ List.nth nodes 3 ] in
           assert_contains s "Fight: Training Slime (visited)";
           assert_contains s "Rest (you are here)";
           assert_contains s "1. Boss: Training Slime" );
         ( "run over: won, lost and cleared" >:: fun _ ->
           assert_contains
             (Ui.render_run_over { run with run_phase = Won })
             "won the run";
           assert_contains
             (Ui.render_run_over { run with run_phase = Lost })
             "run is over";
           let cleared = Ui.render_run_over run in
           assert_contains cleared "cleared";
           assert_contains cleared "Gold 12";
           assert_contains cleared "new" );
       ]

let () =
  run_test_tt_main
    ("ui"
    >::: [ parse_tests; command_tests; help_tests; render_tests; map_tests ])
