% One turn of Cross Universe for units with no abilities: retire, summon, battle. SPDX-License-Identifier: MIT
% Copyright (c) 2026 K. S. Ernest (iFire) Lee. Unofficial; the game is copyright Cross Universe, https://crossuniverse.jp/
int: mine;  set of int: MINE = 1..mine;
array[MINE] of int: attack;  array[MINE] of int: defense;  array[MINE] of int: level;
array[MINE] of bool: shares;  array[MINE] of bool: in_hand;  array[MINE] of bool: retirable;
int: theirs;  set of int: THEIRS = 1..theirs;
array[THEIRS] of int: their_attack;  array[THEIRS] of int: their_defense;  array[THEIRS] of int: their_level;
int: my_life;  int: their_life;  int: mana;
int: weight_damage;  int: weight_kill;  int: weight_board;  int: weight_life;  int: weight_bank;

set of int: SLOT = 1..mine;
set of int: STEP = 1..mine + 1;
int: top = sum(attack) + sum(their_attack);
int: purse = mana + sum(level);
array[MINE] of var 0..2: retire;
var 0..mine: summon;
var bool: early;
array[MINE] of var 0..mine: slot;
array[SLOT] of var 0..theirs: target;

array[SLOT] of var bool: used = [exists(i in MINE)(slot[i] = k) | k in SLOT];
array[SLOT] of var 0..top: power = [sum(i in MINE)(attack[i] * bool2int(slot[i] = k)) | k in SLOT];
array[SLOT] of var 0..top: counter = [sum(j in THEIRS)(their_attack[j] * bool2int(target[k] = j)) | k in SLOT];
array[STEP, MINE] of var bool: stands;
array[STEP, THEIRS] of var bool: their_stands;
array[SLOT, THEIRS] of var bool: kill;
array[SLOT, MINE] of var bool: loss;
array[SLOT] of var bool: survives;
array[SLOT] of var 0..top: hit;
array[SLOT] of var 0..top: hurt;
array[MINE] of var bool: stays;

constraint forall(i in MINE where not in_hand[i])(summon != i);
constraint summon = 0 -> not early;
constraint forall(i in MINE where not retirable[i])(retire[i] = 0);
constraint forall(i, j in MINE where i < j)((retire[i] > 0 /\ retire[j] > 0) -> retire[i] = retire[j]);
constraint stands[1, 1] /\ forall(j in THEIRS)(their_stands[1, j]);
constraint forall(i in MINE where i > 1 /\ not in_hand[i])(stands[1, i] <-> retire[i] != 1);
constraint forall(i in MINE where in_hand[i])(stands[1, i] <-> (summon = i /\ early));
constraint forall(i in MINE)(retire[i] = 2 -> stands[mine + 1, i]);
constraint forall(k in SLOT)(used[k] <-> target[k] > 0);
constraint forall(k in SLOT where k > 1)(used[k] -> used[k - 1]);
constraint forall(i in MINE, k in SLOT)(slot[i] = k -> stands[k, i]);
constraint forall(i, j in MINE where i > 1 /\ i != j)((slot[i] > 0 /\ slot[i] = slot[j]) -> (slot[1] = slot[i] /\ shares[i]));
constraint forall(k in SLOT, j in THEIRS)(target[k] = j -> their_stands[k, j]);
constraint forall(k in SLOT, j in THEIRS where j > 1)(target[k] = 1 -> not their_stands[k, j]);
constraint forall(k in SLOT)(not kill[k, 1] /\ not loss[k, 1]);
constraint forall(k in SLOT, j in THEIRS where j > 1)(kill[k, j] <-> (target[k] = j /\ power[k] > their_defense[j]));
constraint forall(k in SLOT)(survives[k] <-> (used[k] /\ forall(j in THEIRS)(not kill[k, j])));
constraint forall(k in SLOT, i in MINE where i > 1)(loss[k, i] <-> (slot[i] = k /\ slot[1] != k /\ survives[k] /\ counter[k] > defense[i]));
constraint forall(k in SLOT, j in THEIRS)(their_stands[k + 1, j] <-> (their_stands[k, j] /\ not kill[k, j]));
constraint forall(k in SLOT, i in MINE)(stands[k + 1, i] <-> (stands[k, i] /\ not loss[k, i]));
constraint forall(k in SLOT)((target[k] = 1 -> hit[k] = max(0, power[k] - their_defense[1])) /\ (target[k] != 1 -> hit[k] = 0));
constraint forall(k in SLOT)(((slot[1] = k /\ survives[k]) -> hurt[k] = max(0, counter[k] - defense[1])) /\ (not (slot[1] = k /\ survives[k]) -> hurt[k] = 0));
constraint forall(i in MINE where i > 1 /\ not in_hand[i])(stays[i] <-> (stands[mine + 1, i] /\ retire[i] != 2));
constraint forall(i in MINE where in_hand[i])(stays[i] <-> (summon = i /\ (stands[mine + 1, i] \/ not early)));
constraint stays[1];

var 0..purse: early_gain = sum(i in MINE)(level[i] * bool2int(retire[i] = 1));
var 0..purse: late_gain = sum(i in MINE)(level[i] * bool2int(retire[i] = 2));
var 0..purse: cost = sum(i in MINE)(level[i] * bool2int(summon = i));
var 0..purse: left = mana + early_gain + late_gain - cost;
constraint early -> mana + early_gain >= cost;
var 0..their_life: damage = min(their_life, sum(hit));
var 0..my_life: life_lost = min(my_life, sum(hurt));
var int: kills = sum(j in THEIRS where j > 1)(their_level[j] * (1 - bool2int(their_stands[mine + 1, j])));
var int: board = sum(i in MINE where i > 1)(level[i] * bool2int(stays[i]));
var 0..5: bank = min(5, min(5, left) + 5 - level[1]);
var int: objective = weight_life * life_lost - weight_damage * damage - weight_kill * kills - weight_board * board - weight_bank * bank;
solve :: int_search(retire ++ [summon] ++ slot ++ target, smallest, indomain_min) minimize objective;

output ["objective = ", show(objective), ";\nretire = ", show(retire), ";\nsummon = ", show(summon), ";\nearly = ", show(early),
        ";\nslot = ", show(slot), ";\ntarget = ", show(target), ";\n"];
