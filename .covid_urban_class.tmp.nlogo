globals[
  n-infected
  n-recovered
  n-deaths
  total-population
 non-essential-jobs
  lockdown?
]

breed [cities city]
breed [people person]
breed [jobs job]
breed [houses house]

cities-own[
  population
  ;;jobs
  id
]

houses-own[
  house-id
  resident
]

links-own[
 potential-infrastructure
  best
]

jobs-own[
  type-job
  worker ;-id
  is-shop?
]

patches-own[
  city-id
  density
  people-counter
  neighbor-city-id
 ; worker-id
]
people-own[
  alive? ;; 0/1
  age
  infected? ;; 0/10/1
  mobile? ;; 0/1
  immune? ;; 0/1
  time-at-infection
  recovery-time ;; 0-...
  active ;; 1 = at work / 0 = inactive or looking for work
  work-status ;; essential / non-essential
  residence-city ;;
  residence-xy
  home-type ;; collective/individual
;;  access-to-light ;; single-window / multiple-windows / balcony / garden
;;  tenure-type ;; owned / rented / socially-rented / none
  secondary-home ;; 0/1
  my-city-id
  job-id
  class
  house-id
  activity
  activity-at-infection
]

to setup
  ca

 ; ask patches [set people-counter 0 ]
  set lockdown? 0
  setup-cities
  setup-people
  setup-city-links
  setup-jobs

  if secondary-houses?[
  setup-secondary-homes
  ]

 ; ask patches with [pcolor != 0] [

;    set pcolor scale-color orange people-counter max [people-counter] of patches 0
 ; ]


reset-ticks

   ask one-of people [start-infection]
   update-globals
    assign-color

end

to setup-city-links
   ask cities [
    create-links-with other cities
    ask links [
      let t1 end1
      let t2 end2
      set best 0
      let d12 [distance t2] of t1
      set  potential-infrastructure ([population] of end1 * [population] of end2) / ( d12 ^ 2 )
      if potential-infrastructure = max [[potential-infrastructure] of my-out-links] of t1 [set best 1]
    ]

    ask my-out-links with [potential-infrastructure < median [potential-infrastructure] of links / 1.5 and best != 1]
    [
      die
    ]
    if count link-neighbors < 1 [
      create-link-with min-one-of other cities [distance myself]
    ]

    ask patches with [city-id = [id] of myself][
      set neighbor-city-id ([[id] of link-neighbors] of myself)
    ]
  ]
end

to setup-secondary-homes
  let second-home-agentset people with [secondary-home = 1]

  let n-secondary-homes count second-home-agentset
  ask n-of n-secondary-homes patches with [pcolor = 69][
    sprout-houses 1 [
      set shape "sec-house"
      set size 1.4
      set color grey
      set resident one-of second-home-agentset
      let resident-to-remove resident
      set second-home-agentset second-home-agentset with [self != resident-to-remove]
    ]
  ]

  ask houses[
    ask resident [
      set house-id myself
    ]
  ]
end

to setup-cities
  ask patches [set pcolor 69]
   let i 1
  create-cities n-cities [
    setxy random-xcor random-ycor
    while [
      [pcolor] of patch-here != 69
    ] [ setxy random-xcor random-ycor ]
    set id i
    set population max-pop-city / i
    ;set shape "circle"
    ;set color pink
    set size 0
    let p population / 100
    ask patch-here [
      set pcolor 9.9
      set city-id i
      set density n-cities - i + 2

      ask patches in-radius p  [
        set pcolor [pcolor] of myself
        set city-id i
        set density round (n-cities - i + 2) / 3
      ]
       ask patches in-radius (n-cities - i + 2 / 2) [
        set density round (n-cities - i + 2) / 2
      ]
    ]


    set i i + 1
  ]

  ;; source OCDE (2020), Lits d’hôpitaux (indicateur). doi: 10.1787/9b82df80-fr (Consulté le 24 mars 2020)
  ;; in france in 2018 : 6 hospital beds per 1000 hab. = 0.6%
   ;; in france in 2018 : 3 icu beds per 1000 hab. = 0.3%
   set total-population round ( sum [population] of cities )


 ; ask cities with [id = 1] [create-links-with cities with [id = 2]]
 ; ask cities with [count my-links = 0] [
 ;   create-links-with cities with [id = 1]
 ; ]
end


to setup-people
  ask patches with [pcolor != 69] [
    let idc [city-id] of self
    let dens [density] of self
    sprout-people dens [
      set xcor xcor - 0.5 + random-float 1
      set ycor ycor - 0.5 + random-float 1
      set residence-xy list xcor ycor
      set shape "person"
      set color black
      set size 0.75

      set my-city-id idc
      set alive? 1
      set infected? 0
      set mobile? 1
      set immune? 0
      set time-at-infection 0
      set residence-city idc
      set job-id 0
      set class 0
      set house-id 0
      set activity 0
      set activity-at-infection 0
      set recovery-time random-normal average-recovery-time 1

   ;; distribution of people by age from French population projection in 2020, T16F032T2 https://www.insee.fr/fr/statistiques/1906664?sommaire=1906743
       let under20 24
      let from20to59 50
      let from60to74 17

      let a random-float 100
      ifelse (a < under20) [ set age "under-20"][
        ifelse (a < (under20 + from20to59)) [ set age "20-59"][
        ifelse (a < (under20 + from20to59 + from60to74)) [ set age "60-74"][set age "over-75"]
      ]
      ]


      ;; distribution of active workers by age from French population in 2016, Figure 2 https://www.insee.fr/fr/statistiques/3303384?sommaire=3353488
      ;; nb. age categories are not exactly coincidental (÷- 5 years)

      let under24-activity 37
      let from25to49-activity 88
      let from50to64-activity 65

      let b random-float 100
      if [age] of self = "under-20" [
        ifelse (b < under24-activity) [set active 1][set active 0]
      ]
      if [age] of self = "20-59" [
        ifelse (b < from25to49-activity) [set active 1][set active 0]
      ]
      if [age] of self = "60-74" [
        ifelse (b < ( from50to64-activity / 2)) [set active 1][set active 0]
      ]
      if [age] of self = "over-75" [set active 0]


      ;; distribution of active workers by professions in France in 2016 https://www.insee.fr/fr/statistiques/3303413?sommaire=3353488
      ;; large estimate of essential workers = 46.6%
      ;; 7.1% (human health) + 7.4% social + 12.9% commerce + 9.1% public admin + 4.6% finance + 5.5% Transport

     let c random-float 100

       if [active] of self = 1 [
        ifelse (c < essential-industry) [
          set work-status "essential"
        ][
          set work-status "non-essential"
        ]
      ]

      ;;source: https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=1&ved=2ahUKEwizuoyypbHoAhWNgVwKHdERDqIQFjAAegQIBBAB&url=https%3A%2F%2Fwww.insee.fr%2Ffr%2Fstatistiques%2Ffichier%2F2586038%2FLOGFRA17j1_F5.1.pdf&usg=AOvVaw1FYYaTUWdRFyhe9mqPV_zI
      ;; 15% of households have another residence


         ;;source : https://www.insee.fr/fr/statistiques/3620894
      ;; in France 2018 for municipalities with population between 2000 and 100000 residents: 33% collective homes, 66% individual

       let h random-float 100
       ifelse (h < share-collective-housing) [set home-type "collective"][set home-type "individual"]

       let g random-float 100
      if (work-status = "essential" and home-type = "collective")[set class "poor"]
       if (work-status = "non-essential" and home-type = "individual")[
        set class "rich"
        ifelse (g < proba-secondary-home * 2) [set secondary-home 1][set secondary-home 0]
      ]
      if (class = 0)[
        set class "middle"
      ifelse (g < proba-secondary-home) [set secondary-home 1][set secondary-home 0]]

update-patch



    ]
  ]

end

to assign-color

  ask people with [infected? = 0 and immune? = 0][ set color 28]
  ask people with [infected? = 1][ set color 84]
  ask people with [immune? = 1][ set color 35 ]
  ask people with [alive? = 0][ set color black set shape "x"]

end



to setup-jobs
  let n-workers count people with [active = 1]
  let n-essential-workers count people with [work-status = "essential"]
  set non-essential-jobs  n-workers - n-essential-workers

  let essential-workers-agentset people with [work-status = "essential"]

     while [any? essential-workers-agentset]  [
   ask patches with [pcolor != 69] [
   ;     let idc [city-id] of self
      let dens min list ([density] of self * 1.2)  ( count essential-workers-agentset in-radius link-radius)
    sprout-jobs dens [
        set shape "square"
        set size 0.5
        set color 5
        set is-shop? 0
        set type-job "essential"
        set worker one-of essential-workers-agentset in-radius link-radius
        ask worker [set job-id myself]
       ; set worker-id [who] of worker
        ask essential-workers-agentset [
          let worker-to-remove [worker] of myself
          set essential-workers-agentset essential-workers-agentset with [self != worker-to-remove]
        ]
  ]
  ]

  ]

  let n-shops min (list (shop-per-100-inhab * total-population / 100)  (n-essential-workers))
  while [ n-shops >= 1 ] [
    ask one-of jobs with [is-shop? = 0] [
      set is-shop? 1
      set color 25
      set n-shops n-shops - 1
    ]
  ]

   let non-essential-workers-agentset people with [work-status = "non-essential"]
  while [any? non-essential-workers-agentset]  [
   ask patches with [pcolor != 69] [
   ;     let idc [city-id] of self
      let dens min list ([density] of self * 1.5)  ( count non-essential-workers-agentset in-radius link-radius)
    sprout-jobs dens [
        set shape "square"
        set size 0.5
        set color 2
        set is-shop? 0
        set type-job "non-essential"
        set worker one-of non-essential-workers-agentset with [my-city-id = [[city-id] of patch-here] of myself]
       ifelse is-turtle? worker[
        ask worker [set job-id myself]
        ][
           set worker one-of non-essential-workers-agentset with [member? my-city-id [[neighbor-city-id] of patch-here] of myself = true]
           ifelse is-turtle? worker[
        ask worker [set job-id myself]
          ][
           set worker one-of non-essential-workers-agentset
             ask worker [set job-id myself]
          ]
        ]
       ; set worker-id [who] of worker
        ask non-essential-workers-agentset [
          let worker-to-remove [worker] of myself
          set non-essential-workers-agentset non-essential-workers-agentset with [self != worker-to-remove]
        ]
  ]
  ]

  ]


end



to go

  if all? people [infected? = 0]
    [ stop ]
  if all? people [alive? = 0]
    [ stop ]


    if count people with [alive? = 0] > 9 and lockdown? = 0 [
      ask people with [work-status != "essential"] [set mobile? 0]
      if secondary-houses? [
        ask people with [secondary-home = 1] [
          move-to [patch-here] of house-id
          set mobile? 0
        ]
      ]
      set lockdown? 1
      print "Lockdown activated. People flee to their secondary homes"
    ]



  update-health

  ifelse secondary-houses? [
  go-to-work
  go-shopping
  ifelse lockdown? = 0 [
    go-home
    ][
      go-home-or-secondary-house
    ]
  ][
  go-to-work
  go-shopping
  go-home
  ]

;ask patches with [pcolor != 0] [
 ;    set pcolor scale-color orange people-counter max [people-counter] of patches 0
  ;]

  update-globals
    assign-color

  tick

end

to update-globals
 set n-infected count people with [infected? = 1]
 set n-recovered count people with [immune? = 1]
 set n-deaths count people with [alive? = 0]
end

to update-patch
  ask patch-here[
    set people-counter people-counter + 1
  ]
end

to go-to-work
  ask people[

 if job-id != 0[
      if mobile? = 1[
    move-to [patch-here] of job-id
      update-patch
        set activity "work"
      ]
  ]
  ]

  ask people[ if infected? = 1 [ infect-people ]]
end

to go-shopping
   ask people[


    if random average-days-between-shopping = 1 [

    let my-shop one-of jobs with [is-shop? = 1] in-radius radius-movement
    if is-turtle? my-shop[
    move-to [patch-here] of my-shop
          update-patch
        set activity "shop"
    ]
  ]


  ]
    ask people[ if infected? = 1 [ infect-people ]]
end

to  go-home
  ask people [
    setxy item 0 residence-xy item 1 residence-xy
    update-patch
    set activity "home"
  ]
  ask people with [home-type = "collective"][
    if infected? = 1 [
      infect-people
  ]
  ]
end

to  go-home-or-secondary-house
  ask people[
    ifelse secondary-home = 1[
      move-to [patch-here] of house-id
         update-patch
       set activity "home"
    ][
     setxy item 0 residence-xy item 1 residence-xy
    update-patch
       set activity "home"
      if home-type = "collective"[
    if infected? = 1 [
      infect-people
  ]
  ]
]
  ]
end

to infect-people
  if any? people with [patch-here = [patch-here] of myself and immune? = 0][
  ask people with [patch-here = [patch-here] of myself and immune? = 0] [
    let z random 100
    if z < infection-proba  [start-infection]
  ]
  ]
end

to start-infection
  set infected? 1
  set time-at-infection ticks
  set recovery-time random-normal average-recovery-time 2
  set activity-at-infection activity
end

to update-health
  ask people with [infected? = 1][
  if ticks > time-at-infection + recovery-time [recover]

      let y random-float 100
       if y < proba-dying  [set alive? 0 set mobile? 0]

  ]
end

to recover
  set infected? 0
  set immune? 1
end
@#$#@#$#@
GRAPHICS-WINDOW
510
17
1040
548
-1
-1
12.732
1
10
1
1
1
0
0
0
1
-20
20
-20
20
0
0
1
ticks
30.0

BUTTON
46
44
130
77
Initialise
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
1288
339
1411
372
max-pop-city
max-pop-city
200
10000
700.0
100
1
NIL
HORIZONTAL

SLIDER
1073
339
1173
372
n-cities
n-cities
0
10
8.0
1
1
NIL
HORIZONTAL

SLIDER
1072
178
1254
211
essential-industry
essential-industry
0
100
47.0
1
1
NIL
HORIZONTAL

SLIDER
1072
230
1275
263
proba-secondary-home
proba-secondary-home
0
50
5.0
1
1
NIL
HORIZONTAL

SLIDER
1072
284
1282
317
share-collective-housing
share-collective-housing
0
100
50.0
1
1
NIL
HORIZONTAL

TEXTBOX
1074
163
1349
190
share of workers in essential industries
11
0.0
1

TEXTBOX
1074
213
1331
241
share of households with secondary home
11
0.0
1

TEXTBOX
1073
267
1363
295
share of households living in collective housing
11
0.0
1

TEXTBOX
1074
462
1224
480
Unknown statistics
11
0.0
1

TEXTBOX
1074
322
1224
340
Urban context
11
0.0
1

BUTTON
49
100
127
133
Simulate
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
213
42
494
192
Global epidemic situation
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"infected" 1.0 0 -12345184 true "plot count people with [infected? = 1]" "plot count people with [infected? = 1]"
"recovered" 1.0 0 -6459832 true "plot count people with [immune? = 1]" "plot count people with [immune? = 1]"
"dead" 1.0 0 -16777216 true "plot count people with [alive? = 0]\n " "plot count people with [alive? = 0]"
"susceptible" 1.0 0 -408670 true "plot count people with [infected? = 0 and immune? = 0]" "plot count people with [infected? = 0 and immune? = 0]"

SLIDER
1072
393
1186
426
infection-proba
infection-proba
0
100
2.0
1
1
NIL
HORIZONTAL

TEXTBOX
1073
377
1223
395
Epidemiological variables
11
0.0
1

SLIDER
1187
392
1355
425
average-recovery-time
average-recovery-time
0
30
10.0
1
1
NIL
HORIZONTAL

SLIDER
1073
479
1293
512
average-days-between-shopping
average-days-between-shopping
0
10
4.0
1
1
NIL
HORIZONTAL

SLIDER
1200
513
1344
546
shop-per-100-inhab
shop-per-100-inhab
0
20
2.0
1
1
NIL
HORIZONTAL

SLIDER
1073
513
1199
546
radius-movement
radius-movement
0
20
4.0
1
1
NIL
HORIZONTAL

TEXTBOX
1073
57
1223
75
infected person
9
44.0
1

TEXTBOX
1072
69
1222
87
susceptible person
9
67.0
1

TEXTBOX
1073
81
1223
99
immune person
9
105.0
1

TEXTBOX
1073
92
1223
110
shop
9
125.0
1

TEXTBOX
1073
103
1223
121
essential workplace
9
4.0
1

SLIDER
1175
339
1287
372
link-radius
link-radius
0
100
12.0
1
1
NIL
HORIZONTAL

TEXTBOX
1073
114
1223
132
non-essential workplace
9
2.0
1

PLOT
9
200
300
350
% infected per class
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"working class" 1.0 0 -2674135 true "plot (count people with [class = \"poor\" and infected? = 1] * 100)/ count people with [class = \"poor\"] " "plot (count people with [class = \"poor\" and infected? = 1] * 100)/ count people with [class = \"poor\"] "
"middle class" 1.0 0 -1184463 true "plot (count people with [class = \"middle\" and infected? = 1] * 100)/ count people with [class = \"middle\"] " "plot (count people with [class = \"middle\" and infected? = 1] * 100)/ count people with [class = \"middle\"] "
"priviledged" 1.0 0 -12087248 true "plot (count people with [class = \"rich\" and infected? = 1] * 100)/ count people with [class = \"rich\"] " "plot (count people with [class = \"rich\" and infected? = 1] * 100)/ count people with [class = \"rich\"] "

SLIDER
1072
427
1197
460
proba-dying
proba-dying
0
100
0.1
0.1
1
NIL
HORIZONTAL

SWITCH
14
514
193
547
secondary-houses?
secondary-houses?
0
1
-1000

MONITOR
80
381
169
426
Total deaths
count people with [alive? = 0]
17
1
11

PLOT
231
382
497
547
% of population dead
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"working class" 1.0 0 -2674135 true "plot ((count people with [class = \"poor\" and alive? = 0] * 100)/ count people with [class = \"poor\"])" "plot ((count people with [class = \"poor\" and alive? = 0] * 100)/ count people with [class = \"poor\"])"
"middle class" 1.0 0 -4079321 true "plot ((count people with [class = \"middle\" and alive? = 0] * 100)/ count people with [class = \"middle\"])" "plot ((count people with [class = \"middle\" and alive? = 0] * 100)/ count people with [class = \"middle\"])"
"priviledged" 1.0 0 -12087248 true "plot ((count people with [class = \"rich\" and alive? = 0] * 100)/ count people with [class = \"rich\"])" "plot ((count people with [class = \"rich\" and alive? = 0] * 100)/ count people with [class = \"rich\"])"

MONITOR
320
250
563
295
% working-class infections
(100 * count people with [class = \"poor\" and activity-at-infection = \"work\" ] ) /  count people with [class = \"poor\"]
2
1
11

MONITOR
320
302
494
347
% infection from work (RICH)
(100 * count people with [class = \"rich\" and activity-at-infection = \"work\" ] ) /  count people with [class = \"rich\"]
2
1
11

TEXTBOX
320
210
480
242
Did they catch the virus while at work?
13
0.0
1

TEXTBOX
11
159
191
207
What proportion of each social class is infected ?
13
0.0
1

TEXTBOX
214
20
467
52
Where is the epidemic at?
13
0.0
1

TEXTBOX
1073
31
1223
49
Who's who?
13
0.0
1

TEXTBOX
31
360
181
392
How many people died so far?
13
0.0
1

TEXTBOX
232
360
405
392
Who died (by social class)?
13
0.0
1

TEXTBOX
15
479
203
527
Allow richer people to own and isolate in second homes
13
0.0
1

TEXTBOX
41
22
191
40
Setup the world
13
0.0
1

TEXTBOX
31
80
181
98
Start the simulation
13
0.0
1

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

circle 3
true
0
Circle -7500403 false true 0 0 300

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

health-worker
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105
Polygon -2674135 true false 135 90 165 90 165 120 195 120 195 150 165 150 165 180 135 180 135 150 105 150 105 120 135 120

health-worker-mask
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105
Polygon -7500403 true true 120 45 120 75 180 75 180 60
Polygon -1 false false 120 45 180 45 180 75 120 75
Polygon -1 true false 135 75 180 75 180 45 120 45 120 75
Polygon -1 true false 60 150 75 180 60 210 45 180
Polygon -1 true false 240 150 225 180 240 210 255 180
Polygon -2674135 true false 135 120 135 90 165 90 165 120 195 120 195 150 165 150 165 180 135 180 135 150 105 150 105 120

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

person-mask
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105
Polygon -1 true false 105 45 120 45 120 75 180 75 180 45 195 45
Polygon -1 true false 60 150 75 180 60 210 45 180 60 150
Polygon -1 true false 240 150 225 180 240 210 255 180

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sec-house
false
0
Polygon -7500403 false true 75 120 75 270 225 270 225 120 255 120 150 30 45 120

secondary-house
false
0
Rectangle -7500403 false true 60 90 240 240
Line -7500403 true 150 15 255 90
Line -7500403 true 255 90 45 90
Line -7500403 true 45 90 150 15
Rectangle -7500403 false true 135 180 165 240
Rectangle -7500403 false true 180 120 210 150

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.4
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
