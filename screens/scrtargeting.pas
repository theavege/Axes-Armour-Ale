(* Screen used for Look command, Firing a bow, and Throwing projectiles *)

unit scrTargeting;

{$mode objfpc}{$H+}
{$RANGECHECKS OFF}

interface

uses
  SysUtils, Classes, Math, map, entities, video, ui, camera, fov, items, los,
  scrGame, player_stats, crude_dagger, basic_club, staff_minor_scorch, animation,
  globalUtils, arrow;

type
  (* Weapons *)
  Equipment = record
    id, baseDMG: smallint;
    mnuOption: char;
    Name, glyph, glyphColour: shortstring;
    onGround, equppd: boolean;
  end;

type
  (* Enemies *)
  TthrowTargets = record
    id, x, y: smallint;
    distance: single;
    Name: string;
  end;

const
  empty = 'xxx';
  maxWeapons = 11;

var
  (* Target coordinates *)
  targetX, targetY: smallint;
  (* The last safe coordinates *)
  safeX, safeY: smallint;
  (* Throwable items *)
  throwableWeapons: array[0..maxWeapons] of Equipment;
  weaponAmount, selectedTarget, tgtAmount: smallint;
  (* Selected projectile *)
  chosenProjectile: smallint;
  (* List of projectile targets *)
  tgtList: array of TthrowTargets;
  (* Path of arrows *)
  arrowFlightArray: array[1..plyrTargetRange] of TPoint;
  (* Arrow Glyph to use in animation *)
  arrowGlyph: shortstring;
  (* Coordinates where the projectile lands *)
  landingX, landingY: smallint;

(* Calculate what angle of arrow to use *)
function glyphAngle(targetX, targetY: smallint): shortstring;
(* Look around the map *)
procedure look(dir: word);
(* Aim bow and arrow *)
procedure aimBow(dir: word);
(* Fire bow and arrow *)
procedure fireBow;
(* Draw trajectory of arrow *)
procedure drawTrajectory(x1, y1, x2, y2: smallint; g, col: shortstring);
(* Arrow hits an entity *)
procedure arrowHit(x, y: smallint);
(* Confirm there are NPC's and projectiles *)
function canThrow(): boolean;
(* Check if the projectile selection is valid *)
function validProjectile(selection: char): boolean;
(* Choose target for projectile *)
procedure projectileTarget;
(* Cycle between the targets *)
procedure cycleTargets(selection: smallint);
(* Start the Target / Throw process *)
procedure target;
(* Throw projectile at confirmed target *)
procedure chuckProjectile;
(* Remove a thrown item from the ground *)
procedure removeFromGround;
(* Remove a thrown item from inventory *)
procedure removeThrownFromInventory;
(* Repaint the player when exiting look/target screen *)
procedure restorePlayerGlyph;
(* Paint over the message log *)
procedure paintOverMsg;

implementation

uses
  player_inventory, main;

{ Look action }

function glyphAngle(targetX, targetY: smallint): shortstring;
var
  playerX, playerY, Yresult, Xresult, trajectory: smallint;
  angleGlyph: shortstring;
begin
  playerX := entityList[0].posX;
  playerY := entityList[0].posY;
  angleGlyph := '|';
  if (targetX > playerX) then
     begin
       Yresult:=playerY - targetY;
       Xresult := targetX - playerX;
     end
  else if (targetX < playerX) then
     begin
       Yresult := targetY - playerY;
       Xresult:=playerX - targetX;
     end;
  (* Store trajectory *)
  trajectory := Trunc(RadToDeg(arctan2(Yresult, Xresult)));
  (* Calculate glyph *)
  if (playerY = targetY) then
     angleGlyph:='-'
  else if (playerX = targetX) then
     angleGlyph:='|'
  (* If target is to the right of the player *)
  else if (targetX > playerX) then
     begin
       if (trajectory <= 90) and (trajectory >= 68) then
          angleGlyph:='|'
       else if (trajectory < 68) and (trajectory >= 5) then
          angleGlyph:='/'
       else if (trajectory < 5) and (trajectory > -5) then
          angleGlyph:='-'
       else if (trajectory > -68 ) and (trajectory <= -5) then
          angleGlyph:='\'
       else if (trajectory >= -78 ) and (trajectory <= -68) then
          angleGlyph:='|'
     end
  (* If target is to the left of the player *)
  else if (targetX < playerX) then
     begin
       if (trajectory >= -90) and (trajectory <= -68) then
          angleGlyph:='|'
       else if (trajectory > -68) and (trajectory <= -5) then
          angleGlyph:='\'
       else if (trajectory > -5) and (trajectory < 5) then
          angleGlyph:='-'
       else if (trajectory < 68 ) and (trajectory >= 5) then
          angleGlyph:='/'
       else if (trajectory <= 90 ) and (trajectory >= 68) then
          angleGlyph:='|'
     end
     else angleGlyph:='|';

  arrowGlyph := angleGlyph;
  Result := angleGlyph;
end;

procedure look(dir: word);
var
  i: byte;
  healthMsg, playerName: shortstring;
begin
  LockScreenUpdate;
  (* Clear the message log *)
  paintOverMsg;
  (* Display hint text *)
  TextOut(centreX('[x] to exit the Look screen'), 24, 'lightGrey', '[x] to exit the Look screen');
  (* Turn player glyph to an X *)
  entityList[0].glyph := 'X';
  entityList[0].glyphColour := 'white';

  if (dir <> 0) then
  begin
    case dir of
      { N }
      1: Dec(targetY);
      { W }
      2: Dec(targetX);
      { S }
      3: Inc(targetY);
      { E }
      4: Inc(targetX);
      {NE}
      5:
      begin
        Inc(targetX);
        Dec(targetY);
      end;
      { SE }
      6:
      begin
        Inc(targetX);
        Inc(targetY);
      end;
      { SW }
      7:
      begin
        Dec(targetX);
        Inc(targetY);
      end;
      { NW }
      8:
      begin
        Dec(targetX);
        Dec(targetY);
      end;
    end;
    if (map.withinBounds(targetX, targetY) = False) or
      (map.maparea[targetY, targetX].Visible = False) then
    begin
      targetX := safeX;
      targetY := safeY;
    end;

    (* Redraw all NPC's *)
    for i := 1 to entities.npcAmount do
      entities.redrawMapDisplay(i);
    (* Redraw all items *)
    items.redrawItems;
    (* Draw X on target *)
    map.mapDisplay[targetY, targetX].GlyphColour := 'white';
    map.mapDisplay[targetY, targetX].Glyph := 'X';

    (* Check to see if an entity is under the cursor *)
    if (map.isOccupied(targetX, targetY) = True) then
    begin
      (* Check to see if the entity is the player *)
      if (entities.getCreatureID(targetX, targetY) = 0) then
      begin
        healthMsg := 'Health: ' + IntToStr(entities.getCreatureHP(targetX, targetY)) + '/' + IntToStr(entities.getCreatureMaxHP(targetX, targetY));
        playerName := entityList[0].race + ' the ' + entityList[0].description;
        TextOut(centreX(playerName), 21, 'white', playerName);
        TextOut(centreX(healthMsg), 22, 'white', healthMsg);
      end
      else
      (* If another entity *)
      begin
        healthMsg := 'Health: ' + IntToStr(entities.getCreatureHP(targetX, targetY)) + '/' + IntToStr(entities.getCreatureMaxHP(targetX, targetY));
        TextOut(centreX(entities.getCreatureDescription(targetX, targetY)),
          21, 'white', entities.getCreatureDescription(targetX, targetY));
        TextOut(centreX(healthMsg), 22, 'white', healthMsg);
      end;
    end
    (* else to see if an item is under the cursor *)
    else if (items.containsItem(targetX, targetY) = True) then
    begin
      TextOut(centreX(getItemName(targetX, targetY)), 21, 'white', getItemName(targetX, targetY));
      TextOut(centreX(getItemDescription(targetX, targetY)), 22, 'white', getItemDescription(targetX, targetY));
    end
    (* else describe the terrain *)
    else if (map.maparea[targetY, targetX].Glyph = '.') then
      TextOut(centreX('floor'), 21, 'lightGrey', 'floor')
    else if (map.maparea[targetY, targetX].Glyph = '*') then
      TextOut(centreX('floor'), 21, 'lightGrey', 'cave wall')
    else if (map.maparea[targetY, targetX].Glyph = '<') then
      TextOut(centreX('floor'), 21, 'lightGrey', 'stairs leading up')
    else if (map.maparea[targetY, targetX].Glyph = '>') then
      TextOut(centreX('floor'), 21, 'lightGrey', 'stairs leading down');
  end;

  (* Repaint map *)
  camera.drawMap;
  fov.fieldOfView(entityList[0].posX, entityList[0].posY, entityList[0].visionRange, 1);
  UnlockScreenUpdate;
  UpdateScreen(False);
  (* Store the coordinates, so the cursor doesn't get lost off screen *)
  safeX := targetX;
  safeY := targetY;
end;

{ Aim bow }

procedure aimBow(dir: word);
var
  bowCheck, arrowCheck: boolean;
  i, p: byte;
begin
  bowCheck := False;
  arrowCheck := False;
  LockScreenUpdate;
  (* Check if a bow is equipped *)
  if (player_stats.projectileWeaponEquipped = True) then
     bowCheck := True;
  (* Check if arrows are in inventory *)
  if (player_inventory.carryingArrows = True) then
     arrowCheck := True;
  (* If bow equipped and arrows in inventory *)
  if (bowCheck = True) and (arrowCheck = True) then
  begin
       items.redrawItems;
       (* Redraw NPC's *)
       for p := 1 to entities.npcAmount do
           entities.redrawMapDisplay(p);
  (* Clear the message log *)
  paintOverMsg;
  (* Display hint text *)
  TextOut(centreX('[f] to fire your bow'), 23, 'lightGrey', '[f] to fire your bow');
  TextOut(centreX('[x] to exit the targeting screen'), 24, 'lightGrey', '[x] to exit the targeting screen');

  if (dir <> 0) then
  begin
    case dir of
      { N }
      1: Dec(targetY);
      { W }
      2: Dec(targetX);
      { S }
      3: Inc(targetY);
      { E }
      4: Inc(targetX);
      {NE}
      5:
      begin
        Inc(targetX);
        Dec(targetY);
      end;
      { SE }
      6:
      begin
        Inc(targetX);
        Inc(targetY);
      end;
      { SW }
      7:
      begin
        Dec(targetX);
        Inc(targetY);
      end;
      { NW }
      8:
      begin
        Dec(targetX);
        Dec(targetY);
      end;
    end;
    if (map.withinBounds(targetX, targetY) = False) or
      (map.maparea[targetY, targetX].Visible = False) or (map.isWall(targetX, targetY) = True) then
    begin
      targetX := safeX;
      targetY := safeY;
    end;

    (* Redraw all NPC's *)
    for i := 1 to entities.npcAmount do
      entities.redrawMapDisplay(i);
    (* Redraw all items *)
    items.redrawItems;
    (* Draw line from player to target *)
    drawTrajectory(entityList[0].posX, entityList[0].posY, targetX, targetY, glyphAngle(targetX, targetY), 'yellow');
    (* Draw X on target *)
    map.mapDisplay[targetY, targetX].GlyphColour := 'white';
    map.mapDisplay[targetY, targetX].Glyph := 'X';
    (* Store the coordinates, so the cursor doesn't get lost off screen *)
    safeX := targetX;
    safeY := targetY;
    end;
  end
  (* If bow equipped but no arrows in inventory *)
  else if (bowCheck = True) and (arrowCheck = False) then
  begin
       ui.displayMessage('You have no arrows');
       gameState := stGame;
  end
  (* If no bow equipped *)
  else
  begin
      ui.displayMessage('You have no bow to fire');
      gameState := stGame;
  end;
  (* Repaint map *)
  camera.drawMap;
  fov.fieldOfView(entityList[0].posX, entityList[0].posY, entityList[0].visionRange, 1);
  UnlockScreenUpdate;
  UpdateScreen(False);
end;

procedure fireBow;
var
  p: byte;
begin
  (* If the players tile is selected, fire an arrow into the ground *)
  if (targetX = entityList[0].posX) and (targetY = entityList[0].posY) then
  begin
     ui.displayMessage('You fire an arrow into the ground at your feet');
     (* Draw items *)
     items.redrawItems;
     (* redraw NPC's *)
     LockScreenUpdate;
     for p := 1 to entities.npcAmount do
         entities.redrawMapDisplay(p);
     scrTargeting.restorePlayerGlyph;
     ui.clearPopup;;
     UnlockScreenUpdate;
     UpdateScreen(False);
  end
  (* Fire the arrow *)
  else
      animation.arrowAnimation(arrowFlightArray, arrowGlyph, 'white');
  (* Remove an arrow from inventory *)

  (* Return control of game back to stGame *)
  restorePlayerGlyph;
  gameState := stGame;
end;

procedure drawTrajectory(x1, y1, x2, y2: smallint; g, col: shortstring);
var
  i, deltax, deltay, numpixels, d, dinc1, dinc2, x, xinc1, xinc2, y,
  yinc1, yinc2: smallint;
begin
  (* Initialise array *)
  for i := 1 to plyrTargetRange do
  begin
    arrowFlightArray[i].X := 0;
    arrowFlightArray[i].Y := 0;
  end;
  (* Calculate delta X and delta Y for initialisation *)
  deltax := abs(x2 - x1);
  deltay := abs(y2 - y1);
  (* Initialise all vars based on which is the independent variable *)
  if deltax >= deltay then
  begin
    (* x is independent variable *)
    numpixels := deltax + 1;
    d := (2 * deltay) - deltax;
    dinc1 := deltay shl 1;
    dinc2 := (deltay - deltax) shl 1;
    xinc1 := 1;
    xinc2 := 1;
    yinc1 := 0;
    yinc2 := 1;
  end
  else
  begin
    (* y is independent variable *)
    numpixels := deltay + 1;
    d := (2 * deltax) - deltay;
    dinc1 := deltax shl 1;
    dinc2 := (deltax - deltay) shl 1;
    xinc1 := 0;
    xinc2 := 1;
    yinc1 := 1;
    yinc2 := 1;
  end;
  (* Make sure x and y move in the right directions *)
  if x1 > x2 then
  begin
    xinc1 := -xinc1;
    xinc2 := -xinc2;
  end;
  if y1 > y2 then
  begin
    yinc1 := -yinc1;
    yinc2 := -yinc2;
  end;
  (* Start drawing at *)
  x := x1;
  y := y1;
  (* Draw the pixels *)
  for i := 1 to numpixels do
  begin
    if (numpixels <= plyrTargetRange) then
    begin
      if (map.isWall(x, y) = True) then
         exit;
      (* Draw the trajectory *)
      if (map.maparea[y][x].Blocks = True) then
         map.mapDisplay[y, x].GlyphColour := 'red'
      else
          map.mapDisplay[y, x].GlyphColour := col;
      map.mapDisplay[y, x].Glyph := g;
      (* Add to array *)
      arrowFlightArray[i].X := x;
      arrowFlightArray[i].Y := y;
    end;
    if d < 0 then
    begin
      d := d + dinc1;
      x := x + xinc1;
      y := y + yinc1;
    end
    else
    begin
      d := d + dinc2;
      x := x + xinc2;
      y := y + yinc2;
    end;
  end;
end;

procedure arrowHit(x, y: smallint);
var
  opponent: shortstring;
  p: byte;
  opponentID, dmgAmount, rndOption: smallint;
begin
  dmgAmount := 0;
  rndOption := globalUtils.randomRange(0,3);
  (* Get target info *)
  opponentID := getCreatureID(x, y);
  opponent := getCreatureName(x, y);
  if (entityList[opponentID].article = True) then
     opponent := 'the ' + opponent;

  (* Attacking an NPC automatically makes it hostile *)
  entityList[opponentID].state := stateHostile;
  (* Number of turns NPC will follow you if out of sight *)
  entityList[opponentID].moveCount := 10;

  (* Damage is caused by player Dexterity *)

  dmgAmount := player_stats.dexterity - entityList[opponentID].defence;
  (* If it was a hit *)
  if ((dmgAmount - entityList[0].tmrDrunk) > 0) then
  begin
       Dec(entityList[opponentID].currentHP, dmgAmount);
       (* If it was a killing blow *)
       if (entityList[opponentID].currentHP < 1) then
       begin
          ui.writeBufferedMessages;
          ui.bufferMessage('You kill ' + opponent);
          entities.killEntity(opponentID);
          entityList[0].xpReward := entities.entityList[0].xpReward + entityList[opponentID].xpReward;
          ui.updateXP;
       end
       else
           begin
             if (rndOption = 0) then
                  ui.bufferMessage('The arrow wounds ' + opponent)
             else if (rndOption = 1) then
                  ui.bufferMessage('The arrow hits ' + opponent)
             else
                 ui.bufferMessage('The arrow strikes ' + opponent);
           end;
      end
      else
         ui.bufferMessage('The arrow glances off ' + opponent);

  (* Chance of arrow being damaged or recovered *)
  rndOption := globalUtils.randomRange(0,2);
  if (rndOption <> 2) then
  { Create an arrow }
  begin
    arrow.createArrow(targetX, targetY);
    Inc(indexID);
  end;

  ui.writeBufferedMessages;
  (* Remove arrow from inventory *)
  player_inventory.removeArrow;
  (* Draw items *)
  items.redrawItems;
  for p := 1 to entities.npcAmount do
      entities.redrawMapDisplay(p);
  scrTargeting.restorePlayerGlyph;
  ui.clearPopup;;
  UnlockScreenUpdate;
  UpdateScreen(False);
  (* Increase turn counter for this action *)
  Inc(entityList[0].moveCount);
  gameState := stGame;
  main.gameLoop;
end;

{ Throw function }

function canThrow(): boolean;
var
  projectileAvailable, NPCinRange: boolean;
  i, b: byte;
  mnuChar: char;
begin
  (* Initialise variables *)
  projectileAvailable := False;
  NPCinRange := False;
  i := 0;
  b := 0;
  mnuChar := 'a';
  Result := False;
  {       Check for projectiles     }

  (* Initialise array *)
  for b := 0 to maxWeapons do
  begin
    throwableWeapons[b].id := b;
    throwableWeapons[b].Name := empty;
    throwableWeapons[b].mnuOption := 'x';
    throwableWeapons[b].baseDMG := 0;
    throwableWeapons[b].glyph := 'x';
    throwableWeapons[b].glyphColour := 'x';
    throwableWeapons[b].onGround := False;
    throwableWeapons[b].equppd := False;
  end;

  (* Check inventory for an item to throw *)
  for b := 0 to maxWeapons - 1 do
  begin
    if (inventory[b].throwable = True) then
    begin
      (* Add to list of throwable weapons *)
      throwableWeapons[b].id := inventory[b].id;
      throwableWeapons[b].Name := inventory[b].Name;
      throwableWeapons[b].mnuOption := mnuChar;
      throwableWeapons[b].baseDMG := inventory[b].throwDamage;
      throwableWeapons[b].glyph := inventory[b].glyph;
      throwableWeapons[b].glyphColour := inventory[b].glyphColour;
      throwableWeapons[b].onGround := False;
      if (inventory[b].equipped = True) then
         throwableWeapons[b].equppd := True
      else
        throwableWeapons[b].equppd := False;
      Inc(mnuChar);
      Inc(weaponAmount);
      projectileAvailable := True;
    end;
  end;

  (* Check the ground under the player for an item to throw *)
  if (items.containsItem(entityList[0].posX, entityList[0].posY) = True) and (items.isItemThrowable(entityList[0].posX, entityList[0].posY) = True) then
  begin
      (* Add to list of throwable weapons *)
      throwableWeapons[b].id := items.getItemID(entityList[0].posX, entityList[0].posY);
      throwableWeapons[b].Name := items.getItemName(entityList[0].posX, entityList[0].posY);
      throwableWeapons[b].mnuOption := mnuChar;
      throwableWeapons[b].baseDMG := items.getThrowDamage(entityList[0].posX, entityList[0].posY);
      throwableWeapons[b].glyph := items.getItemGlyph(entityList[0].posX, entityList[0].posY);
      throwableWeapons[b].glyphColour := items.getItemColour(entityList[0].posX, entityList[0].posY);
      throwableWeapons[b].onGround := True;
      throwableWeapons[b].equppd := False;
      Inc(weaponAmount);
      projectileAvailable := True;
  end;

  (* If there are no projectiles available *)
  if (projectileAvailable = False) then
  begin
    ui.displayMessage('There is nothing you can throw');
    restorePlayerGlyph;
    (* Redraw all NPC's *)
    for i := 1 to entities.npcAmount do
      entities.redrawMapDisplay(i);
    (* Redraw all items *)
    items.redrawItems;
    UnlockScreenUpdate;
    UpdateScreen(False);
    main.gameState := stGame;
    exit;
  end;
  {       Check for NPC's in range     }

  (* Get a list of all entities in view *)
  for i := 1 to entities.npcAmount do
  begin
    (* First check an NPC is visible (and not dead) *)
    if (entityList[i].inView = True) and (entityList[i].isDead = False) then
      NPCinRange := True;
  end;

  (* If there are no enemies in sight *)
  if (NPCinRange = False) then
  begin
    ui.displayMessage('There are no enemies in sight');
    restorePlayerGlyph;
    (* Redraw all NPC's *)
    for i := 1 to entities.npcAmount do
      entities.redrawMapDisplay(i);
    (* Redraw all items *)
    items.redrawItems;
    UnlockScreenUpdate;
    UpdateScreen(False);
    main.gameState := stGame;
    exit;
  end;

  (* Return True if there are projectiles and enemies *)
  if (projectileAvailable = True) and (NPCinRange = True) then
    Result := True;
end;

function validProjectile(selection: char): boolean;
var
  i: byte;
begin
  Result := False;
  for i := 0 to maxWeapons do
  begin
    if (throwableWeapons[i].mnuOption = selection) then
    begin
      chosenProjectile := i;
      Result := True;
      gameState := stTarget;
    end;
  end;
end;

procedure projectileTarget;
var
  i, dx, dy, closestID: smallint;
  i3: single;
begin
  LockScreenUpdate;
  (* Clear the message log *)
  paintOverMsg;
  (*  Initialise variables and array *)
  i := 0;
  i3 := 30.0;
  tgtAmount := 1;
  closestID := 0;
  SetLength(tgtList, 0);

  (* Check if any enemies are near *)
  for i := 1 to entities.npcAmount do
  begin
    (* First check an NPC is visible (and not dead) *)
    if (entityList[i].inView = True) and (entityList[i].isDead = False) then
    begin
      (* Add NPC to list of targets *)
      SetLength(tgtList, tgtAmount);
      tgtList[tgtAmount - 1].id := i;
      tgtList[tgtAmount - 1].x := entityList[i].posX;
      tgtList[tgtAmount - 1].y := entityList[i].posY;
      tgtList[tgtAmount - 1].Name := entityList[i].race;
      (* Calculate distance from the player *)
      dx := entityList[0].posX - entityList[i].posX;
      dy := entityList[0].posY - entityList[i].posY;
      (* Add the distance to the array *)
      tgtList[tgtAmount - 1].distance := sqrt(dx ** 2 + dy ** 2);
      Inc(tgtAmount);
    end;
  end;

  (* Get the closest target *)
  for i := Low(tgtList) to High(tgtList) do
  begin
    if (tgtList[i].distance < i3) and (tgtList[i].Name <> empty) then
    begin
      i3 := tgtList[i].distance;
      closestID := i;
    end;
  end;
  selectedTarget := closestID;
  cycleTargets(closestID);
end;

procedure cycleTargets(selection: smallint);
var
  i: smallint;
  targetName: string;
begin
  gameState := stSelectTarget;
  targetName := '';
  ui.clearPopup;
  paintOverMsg;
  (* Redraw all NPC's *)
  for i := 1 to entities.npcAmount do
    entities.redrawMapDisplay(i);
  (* Redraw all items *)
  items.redrawItems;

  if (selection < 900) then
    (* Highlight the closest NPC *)
    targetName := tgtList[selection].Name

  (* Cycle through the NPC's to beginning of list *)
  else if (selection = 999) then
  begin
    if (selectedTarget > Low(tgtList)) then
    begin
      Dec(selectedTarget);
      targetName := tgtList[selectedTarget].Name;
    end
    else
    begin
      selectedTarget := High(tgtList);
      targetName := tgtList[selectedTarget].Name;
    end;
  end
  (* Cycle through the NPC's to end of list *)
  else if (selection = 998) then
  begin
    if (selectedTarget < High(tgtList)) then
    begin
      Inc(selectedTarget);
      targetName := tgtList[selectedTarget].Name;
    end
    else
    begin
      selectedTarget := Low(tgtList);
      targetName := tgtList[selectedTarget].Name;
    end;
  end;

  (* Highlight the targeted NPC *)
  map.mapDisplay[tgtList[selectedTarget].y, tgtList[selectedTarget].x].GlyphColour := 'pinkBlink';
  (* Help text *)
  TextOut(centreX(targetName), 22, 'white', targetName);
  TextOut(centreX('Left and Right to cycle between targets'), 23, 'lightGrey', 'Left and Right to cycle between targets');
  TextOut(centreX('[t] Throw ' + throwableWeapons[chosenProjectile].Name + '  |  [x] Cancel'), 24, 'lightGrey', '[t] Throw ' + throwableWeapons[chosenProjectile].Name + '  |  [x] Cancel');

  (* Repaint map *)
  camera.drawMap;
  fov.fieldOfView(entityList[0].posX, entityList[0].posY, entityList[0].visionRange, 1);
  UnlockScreenUpdate;
  UpdateScreen(False);
end;

procedure target;
var
  i, yPOS: byte;
  lastOption: char;
  targetOptsMessage: string;
begin
  LockScreenUpdate;
  (* Clear the message log *)
  paintOverMsg;
  (* Initialise variables *)
  yPOS := 0;
  weaponAmount := 0;
  lastOption := 'a';
  targetOptsMessage := 'Select something to throw';

  (* Check if player can throw something at someone *)
  if (canThrow() = True) then
  begin
    (* Display list of items for player to select *)
    yPOS := (19 - weaponAmount);
    for i := 0 to maxWeapons do
    begin
      if (throwableWeapons[i].Name <> empty) then
      begin
        if (throwableWeapons[i].equppd = True) then
           TextOut(10, yPOS, 'white', '[' + throwableWeapons[i].mnuOption + '] ' + throwableWeapons[i].Name + ' [equipped]')
        (* Projectiles on the ground *)
        else if (throwableWeapons[i].onGround = True) then
          TextOut(10, yPOS, 'white', '[' + throwableWeapons[i].mnuOption + '] ' + throwableWeapons[i].Name + ' [on the ground]')
        (* Everything else *)
        else
          TextOut(10, yPOS, 'white', '[' + throwableWeapons[i].mnuOption + '] ' + throwableWeapons[i].Name);
        Inc(yPOS);
      end;
    end;

    (* Get the range of choices *)
    for i := 0 to maxWeapons do
    begin
      if (throwableWeapons[i].Name <> empty) then
        lastOption := throwableWeapons[i].mnuOption;
    end;
    if (lastOption <> 'a') then
      targetOptsMessage := 'a - ' + lastOption + ' to select something to throw';

    TextOut(centreX(targetOptsMessage), 23, 'white', targetOptsMessage);
    TextOut(centreX('[x] to exit the Throw screen'), 24, 'lightGrey', '[x] to exit the Throw screen');
    UnlockScreenUpdate;
    UpdateScreen(False);
    (* Wait for selection *)
    gameState := stSelectAmmo;
  end
  else
  begin
    (* Repaint map *)
    camera.drawMap;
    fov.fieldOfView(entityList[0].posX, entityList[0].posY, entityList[0].visionRange, 1);
    UnlockScreenUpdate;
    UpdateScreen(False);
    gameState := stGame;
    exit;
  end;
end;

procedure chuckProjectile;
var
  tgtDistance, dex, damage, dmgAmount, diff, i: smallint;
  opponent: shortstring;
begin
  (* Initialise variables *)
  landingX := 0;
  landingY := 0;
  (* Get the opponents name *)
  opponent := entityList[tgtList[selectedTarget].id].race;
  if (entityList[tgtList[selectedTarget].id].article = True) then
    opponent := 'the ' + opponent;

  (* Attacking an NPC automatically makes it hostile *)
  entityList[tgtList[selectedTarget].id].state := stateHostile;
  (* Number of turns NPC will follow you if out of sight *)
  entityList[tgtList[selectedTarget].id].moveCount := 10;

  (* Calculate damage caused *)

  { Convert distance to target from real number to integer }
   tgtDistance := round(tgtList[selectedTarget].distance);
  { Get the players Dexterity }
  dex := player_stats.dexterity;
  { if dex > tgtDistance = the remainder is added to projectile damage
    if dex < tgtDistance = the difference is removed from the damage.
    Closer targets take more damage                                    }
  damage := throwableWeapons[chosenProjectile].baseDMG;
  (* Add the difference to damage *)
  if (dex > tgtDistance) then
  begin
    diff := dex - tgtDistance;
    Inc(damage, diff);
  end
  else
  (* Subtract the difference from damage *)
  begin
    diff := dex - tgtDistance;
    if (diff > 0) and (diff < damage) then
       Dec(damage, diff)
    else
      begin
        diff := 0;
        damage := 0;
      end;
  end;

  (* Calculate the path of the projectile *)
  los.playerProjectilePath(entityList[0].posX, entityList[0].posY, tgtList[selectedTarget].x, tgtList[selectedTarget].y, throwableWeapons[chosenProjectile].glyph, throwableWeapons[chosenProjectile].glyphColour);

  (* Apply damage *)
  if (damage = 0) then
     ui.bufferMessage('The ' + throwableWeapons[chosenProjectile].Name + ' misses')
  else
    begin
      dmgAmount := damage - entityList[tgtList[selectedTarget].id].defence;
      (* If it was a hit *)
      if ((dmgAmount - entityList[0].tmrDrunk) > 0) then
      begin
        Dec(entityList[tgtList[selectedTarget].id].currentHP, dmgAmount);
        (* If it was a killing blow *)
        if (entityList[tgtList[selectedTarget].id].currentHP < 1) then
        begin
          ui.writeBufferedMessages;
          ui.bufferMessage('You kill ' + opponent);
          entities.killEntity(tgtList[selectedTarget].id);
          entityList[0].xpReward := entities.entityList[0].xpReward + entityList[tgtList[selectedTarget].id].xpReward;
          ui.updateXP;
          LockScreenUpdate;
          (* Restore the game map *)
          main.returnToGameScreen;
          (* Restore screen *)
          paintOverMsg;
          ui.restoreMessages;
          UnlockScreenUpdate;
          UpdateScreen(False);
          main.gameState := stGame;
        end
        else
            ui.bufferMessage('The ' + throwableWeapons[chosenProjectile].Name + ' hits ' + opponent);
      end
      else
         ui.bufferMessage('The ' + throwableWeapons[chosenProjectile].Name + ' doesn''t injure ' + opponent);
    end;

  (* Remove item from ground or inventory *)
  if (throwableWeapons[chosenProjectile].onGround = True) then
    removeFromGround
  else
    removeThrownFromInventory;

  ui.writeBufferedMessages;

  LockScreenUpdate;
  (* Restore the game map *)
  main.returnToGameScreen;
  (* Restore screen *)
  paintOverMsg;
  ui.restoreMessages;

  (* Redraw all NPC's *)
    for i := 1 to entities.npcAmount do
      entities.redrawMapDisplay(i);
  UnlockScreenUpdate;
  UpdateScreen(False);
  (* Increase turn counter for this action *)
  Inc(entityList[0].moveCount);
  main.gameState := stGame;
  main.gameLoop;
 end;

procedure removeFromGround;
var
  i, itmID: smallint;
begin
  i := 0;
  for i := 0 to High(itemList) do
    if (entityList[0].posX = itemList[i].posX) and (entityList[0].posY = itemList[i].posY) and (itemList[i].onMap = True) then
       itmID := i;

   (* Weapon damage for edged weapons *)
  case itemList[i].useID of
       2: crude_dagger.thrownDamaged(i, False);
  end;

  (* Rocks break on impact *)
  if (itemList[itmID].itemName <> 'rock') then
  begin
       itemList[itmID].posX:=landingX;
       itemList[itmID].posY:=landingY;
  end
  else
  begin
(* Set an empty flag for the rock on the map, this gets deleted when saving the map *)
  with itemList[itmID] do
      begin
          itemName := 'empty';
          itemDescription := '';
          itemArticle := '';
          itemType := itmEmptySlot;
          itemMaterial := matEmpty;
          useID := 1;
          glyph := 'x';
          glyphColour := 'lightCyan';
          inView := False;
          posX := 1;
          posY := 1;
          NumberOfUses := 0;
          onMap := False;
          throwable := False;
          throwDamage := 0;
          dice := 0;
          adds := 0;
          discovered := False;
      end;
  ui.bufferMessage('The rock breaks on impact');
  end;
end;

procedure removeThrownFromInventory;
var
  itemNumber, dmgID: smallint;
  newItem: Item;
begin
  itemNumber := throwableWeapons[chosenProjectile].id;
  dmgID := player_inventory.inventory[itemNumber].id;

  (* Weapon damage for edged weapons *)
  case player_inventory.inventory[itemNumber].useID of
       2: crude_dagger.thrownDamaged(dmgID, True);
  end;

  (* Rocks break on impact *)
  if (throwableWeapons[chosenProjectile].Name <> 'rock') then
  { Create an item }
  begin
    newItem.itemID := indexID;
    newItem.itemName := player_inventory.inventory[itemNumber].Name;
    newItem.itemDescription := player_inventory.inventory[itemNumber].description;
    newItem.itemArticle := player_inventory.inventory[itemNumber].article;
    newItem.itemType := player_inventory.inventory[itemNumber].itemType;
    newItem.itemMaterial := player_inventory.inventory[itemNumber].itemMaterial;
    newItem.useID := player_inventory.inventory[itemNumber].useID;
    newItem.glyph := player_inventory.inventory[itemNumber].glyph;
    newItem.glyphColour := player_inventory.inventory[itemNumber].glyphColour;
    newItem.inView := True;
    newItem.posX := landingX;
    newItem.posY := landingY;
    newItem.NumberOfUses := player_inventory.inventory[itemNumber].numUses;
    newItem.onMap := False;
    newItem.throwable := player_inventory.inventory[itemNumber].throwable;
    newItem.throwDamage := player_inventory.inventory[itemNumber].throwDamage;
    newItem.discovered := True;
    newItem.adds := player_inventory.inventory[itemNumber].adds;
    newItem.dice := player_inventory.inventory[itemNumber].dice;
    Inc(indexID);

  { Place item on the game map }
  SetLength(itemList, Length(itemList) + 1);
  Insert(newitem, itemList, Length(itemList));
  end
  else
      ui.bufferMessage('The rock breaks on impact');

  (* Unequip weapon if equipped *)
  if (throwableWeapons[chosenProjectile].equppd = True) then
  begin
       case player_inventory.inventory[itemNumber].useID of
         2: crude_dagger.throw(itemNumber);
         4: basic_club.throw;
         8: staff_minor_scorch.throw;
       end;
  end;

  (* Remove from inventory *)
  player_inventory.inventory[itemNumber].Name := 'Empty';
  player_inventory.inventory[itemNumber].equipped := False;
  player_inventory.inventory[itemNumber].description := 'x';
  player_inventory.inventory[itemNumber].article := 'x';
  player_inventory.inventory[itemNumber].itemType := itmEmptySlot;
  player_inventory.inventory[itemNumber].itemMaterial := matEmpty;
  player_inventory.inventory[itemNumber].glyph := 'x';
  player_inventory.inventory[itemNumber].glyphColour := 'x';
  player_inventory.inventory[itemNumber].inInventory := False;
  player_inventory.inventory[itemNumber].numUses := 0;
  player_inventory.inventory[itemNumber].throwable := False;
  player_inventory.inventory[itemNumber].throwDamage := 0;
  player_inventory.inventory[itemNumber].useID := 0;
  player_inventory.inventory[itemNumber].adds := 0;
  player_inventory.inventory[itemNumber].dice := 0;
end;

{ Repaint screen }

procedure restorePlayerGlyph;
begin
  LockScreenUpdate;
  entityList[0].glyph := '@';
  if (entityList[0].stsPoison = True) then
    entityList[0].glyphColour := 'green'
  else
    entityList[0].glyphColour := 'yellow';
  (* Restore the game map *)
  camera.drawMap;
  fov.fieldOfView(entityList[0].posX, entityList[0].posY, entityList[0].visionRange, 1);
  (* Repaint the message log *)
  paintOverMsg;
  ui.restoreMessages;
  UnlockScreenUpdate;
  UpdateScreen(False);
end;

procedure paintOverMsg;
var
  x, y: smallint;
begin
  for y := 21 to 25 do
  begin
    for x := 1 to scrGame.minX do
    begin
      TextOut(x, y, 'black', ' ');
    end;
  end;
end;

end.
