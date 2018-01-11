#define TOTAL_FUCKING_POWER     200
#define WALL_FUCKING_PRICE      100
#define MACHINERY_FUCKING_PRICE 80
#define STRUCTURE_FUCKING_PRICE 60
#define ITEM_FUCKING_PRICE      40

/obj/item/projectile/plasma_charge
	name = "plasma charge"
	//icon = "" //TODO
	icon_state = "plasma" //TODO
	damage = 60
	kill_count = 5//how much turfs can cross this projectile befor get fucked
	var/plasma_force = TOTAL_FUCKING_POWER


/obj/item/projectile/plasma_charge/proc/check_plasma_force()
	if(plasma_force >= 0)
		return TRUE
	else
		return FALSE

/obj/item/projectile/plasma_charge/get_structure_damage()
	if(check_plasma_force())
		world << "proj's force - [plasma_force]"
		return plasma_force
	else
		return FALSE

/obj/item/projectile/plasma_charge/on_hit(var/atom/target, var/blocked = 0, var/def_zone = null)
	world << "[src]/on_hit"

	try_dismantle(target)
	world << "force decreased : [plasma_force]"
	return TRUE


/obj/item/projectile/plasma_charge/on_impact(var/atom/A)
	impact_effect(effect_transform)		// generate impact effect
	playsound(src, "hitsound_wall", 50, 1, -2)
	try_dismantle(A)
	world << "[src]/on_impact. damage = [src.get_structure_damage()]"
	return

/obj/item/projectile/plasma_charge/proc/try_dismantle(var/atom/A)
	world << "try_dismantle"
	if(!check_plasma_force())
		return

	if(istype(A, /obj/item))
		world << "is item"
		if(!plasma_force > ITEM_FUCKING_PRICE)
			return
		qdel(A)
		plasma_force -= ITEM_FUCKING_PRICE
		kill_count--
		return
	else if(istype(A, /obj/structure))
		world << "is structure"
		if(!plasma_force > STRUCTURE_FUCKING_PRICE)
			return
		qdel(A)//A.bullet_act(src)//get shot or qdeling it
		plasma_force -= STRUCTURE_FUCKING_PRICE
		kill_count--
		return
	else if(istype(A, /obj/machinery))
		world << "is machinery"
		if(!plasma_force > MACHINERY_FUCKING_PRICE)
			return
		qdel(A)
		plasma_force -= MACHINERY_FUCKING_PRICE
		kill_count -= 2
	else if(iswall(A))
		world << "is wall"
		if(!plasma_force > WALL_FUCKING_PRICE)
			return
		var/turf/simulated/wall/W = A
		W.dismantle_wall(1)
		plasma_force -= WALL_FUCKING_PRICE
		kill_count -= 2
		return

/obj/item/projectile/plasma_charge/Bump(atom/A as mob|obj|turf|area, forced=0)
	world << "[src]/Bump"
	if(A == src)
		return FALSE //no

	if(A == firer)
		loc = A.loc
		return FALSE //cannot shoot yourself

	if((bumped && !forced) || (A in permutated))
		return FALSE

	var/passthrough = 0 //if the projectile should continue flying
	var/distance = get_dist(starting,loc)

	bumped = TRUE
	world << "Bump checks passed"
	if(ismob(A))
		world << "ismob proceeding"
		var/mob/M = A
		if(isliving(A))
			//if they have a neck grab on someone, that person gets hit instead
			var/obj/item/weapon/grab/G = locate() in M
			if(G && G.state >= GRAB_NECK)
				visible_message(SPAN_DANGER("\The [M] uses [G.affecting] as a shield!"))
				if(Bump(G.affecting, forced=1))
					return //If Bump() returns 0 (keep going) then we continue on to attack M.

			passthrough = !attack_mob(M, distance)
		else
			passthrough = TRUE //so ghosts don't stop bullets
	else
		world << "!ismob"
		passthrough = (A.bullet_act(src, def_zone) == PROJECTILE_CONTINUE) //backwards compatibility
		if(isturf(A))
			world << "isturf"
			for(var/obj/O in A)
				O.bullet_act(src)
			for(var/mob/living/M in A)
				attack_mob(M, distance)
		world << "end of deleting"

	world << "Bump middle"

	//penetrating projectiles can pass through things that otherwise would not let them
	if(!passthrough && penetrating > 0)
		if(check_penetrate(A))
			passthrough = TRUE
		penetrating--

	//the bullet passes through a dense object!
	if(passthrough)
		//move ourselves onto A so we can continue on our way.
		if(A)
			if(istype(A, /turf))
				loc = A
			else
				loc = A.loc
			permutated.Add(A)
		bumped = FALSE //reset bumped variable!
		return FALSE

	//stop flying
	on_impact(A)

	if(plasma_force <= 0)
		qdel(src)
	/*density = FALSE
	invisibility = 101

	qdel(src)*/ //do not delete it after bumping solid objects
	return TRUE

/obj/item/projectile/bullet
	name = "bullet"
	icon_state = "bullet"
	damage = 60
	damage_type = BRUTE
	nodamage = 0
	check_armour = "bullet"
	embed = 1
	sharp = 1
	hitsound_wall = "ric_sound"
	var/mob_passthrough_check = 0

	muzzle_type = /obj/effect/projectile/bullet/muzzle

/obj/item/projectile/bullet/on_hit(var/atom/target, var/blocked = 0)
	if (..(target, blocked))
		var/mob/living/L = target
		shake_camera(L, 3, 2)

/obj/item/projectile/bullet/attack_mob(var/mob/living/target_mob, var/distance, var/miss_modifier)
	if(penetrating > 0 && damage > 20 && prob(damage))
		mob_passthrough_check = 1
	else
		mob_passthrough_check = 0
	return ..()

/obj/item/projectile/bullet/can_embed()
	//prevent embedding if the projectile is passing through the mob
	if(mob_passthrough_check)
		return 0
	return ..()

/obj/item/projectile/bullet/check_penetrate(var/atom/A)
	if(!A || !A.density) return 1 //if whatever it was got destroyed when we hit it, then I guess we can just keep going

	if(istype(A, /obj/mecha))
		return 1 //mecha have their own penetration handling

	if(ismob(A))
		if(!mob_passthrough_check)
			return 0
		if(iscarbon(A))
			damage *= 0.7 //squishy mobs absorb KE
		return 1

	var/chance = 0
	if(istype(A, /turf/simulated/wall))
		var/turf/simulated/wall/W = A
		chance = round(damage/W.material.integrity*180)
	else if(istype(A, /obj/machinery/door))
		var/obj/machinery/door/D = A
		chance = round(damage/D.maxhealth*180)
		if(D.glass) chance *= 2
	else if(istype(A, /obj/structure/girder))
		chance = 100
	else if(istype(A, /obj/machinery) || istype(A, /obj/structure))
		chance = damage

	if(prob(chance))
		if(A.opacity)
			//display a message so that people on the other side aren't so confused
			A.visible_message(SPAN_WARNING("\The [src] pierces through \the [A]!"))
		return 1

	return 0

//For projectiles that actually represent clouds of projectiles
/obj/item/projectile/bullet/pellet
	name = "shrapnel" //'shrapnel' sounds more dangerous (i.e. cooler) than 'pellet'
	damage = 20
	//icon_state = "bullet" //TODO: would be nice to have it's own icon state
	var/pellets = 4			//number of pellets
	var/range_step = 2		//projectile will lose a fragment each time it travels this distance. Can be a non-integer.
	var/base_spread = 90	//lower means the pellets spread more across body parts. If zero then this is considered a shrapnel explosion instead of a shrapnel cone
	var/spread_step = 10	//higher means the pellets spread more across body parts with distance

/obj/item/projectile/bullet/pellet/Bumped()
	. = ..()
	bumped = 0 //can hit all mobs in a tile. pellets is decremented inside attack_mob so this should be fine.

/obj/item/projectile/bullet/pellet/proc/get_pellets(var/distance)
	var/pellet_loss = round((distance - 1)/range_step) //pellets lost due to distance
	return max(pellets - pellet_loss, 1)

/obj/item/projectile/bullet/pellet/attack_mob(var/mob/living/target_mob, var/distance, var/miss_modifier)
	if (pellets < 0) return 1

	var/total_pellets = get_pellets(distance)
	var/spread = max(base_spread - (spread_step*distance), 0)

	//shrapnel explosions miss prone mobs with a chance that increases with distance
	var/prone_chance = 0
	if(!base_spread)
		prone_chance = max(spread_step*(distance - 2), 0)

	var/hits = 0
	for (var/i in 1 to total_pellets)
		if(target_mob.lying && target_mob != original && prob(prone_chance))
			continue

		//pellet hits spread out across different zones, but 'aim at' the targeted zone with higher probability
		//whether the pellet actually hits the def_zone or a different zone should still be determined by the parent using get_zone_with_miss_chance().
		var/old_zone = def_zone
		def_zone = ran_zone(def_zone, spread)
		if (..()) hits++
		def_zone = old_zone //restore the original zone the projectile was aimed at

	pellets -= hits //each hit reduces the number of pellets left
	if (hits >= total_pellets || pellets <= 0)
		return 1
	return 0

/obj/item/projectile/bullet/pellet/get_structure_damage()
	var/distance = get_dist(loc, starting)
	return ..() * get_pellets(distance)

/obj/item/projectile/bullet/pellet/Move()
	. = ..()

	//If this is a shrapnel explosion, allow mobs that are prone to get hit, too
	if(. && !base_spread && isturf(loc))
		for(var/mob/living/M in loc)
			if(M.lying || !M.CanPass(src, loc)) //Bump if lying or if we would normally Bump.
				if(Bump(M)) //Bump will make sure we don't hit a mob multiple times
					return
