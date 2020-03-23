globals[
  n-infected
  n-recovered
  n-deaths
  n-available-beds
]

breed [cities city]
breed [people person]

cities-own[
  population
  jobs
  hospital
  available-beds
  health-workers
]

patches-own[
  city-id
]
people-own[
  alive? ;; 0/1
  infected? ;; 0/1
  serious-symptoms? ;; 0/1
  mobile? ;; 0/1
  immune? ;; 0/1
  time-since-infection ;; 0-...
  recovery-time ;; 0-...
  viral-charge ;; high / medium / low
  use-protection ;; yes / no / partially
  age ;; under-20 / 20-59 / 60-74 / over-75
  active ;; 1 = at work / 0 = inactive or looking for work
  work-status ;; essential / non-essential
  household-status ;; alone / couple / with-children
  caring-away-status ;; care / no-care
  residence-city ;;
  home-type ;; collective/individual
;;  access-to-light ;; single-window / multiple-windows / balcony / garden
;;  tenure-type ;; owned / rented / socially-rented / none
  secondary-home ;; 0/1
  comorbidity ;; 0/1
  repatriated ;; 0/1
]

to setup
  ca
  setup-cities
  setup-people
  reset-ticks
end

to setup-cities
  ask patches [set pcolor white]
   let i 1
  create-cities n-cities [
    setxy random-xcor random-ycor
    while [
      [pcolor] of patch-here != white
    ] [ setxy random-xcor random-ycor ]
    set population max-pop-city / i
    set shape "circle"
    set color pink
    set size population / 100
    let p population / 100
    ask patch-here [
      set pcolor 120 + i
      set city-id i
      ask patches in-radius p  [
        set pcolor [pcolor] of myself
        set city-id i
      ]
    ]
    set i i + 1
  ]
end


to setup-people
  ask patches with [pcolor != white] [
    let idc [city-id] of self
    sprout-people 1 [

      set shape "person"
      set color black
      set size 1

      set alive? 1
      set infected? 0
      set mobile? 1
      set serious-symptoms? 0
      set immune? 0
      set time-since-infection 0
      set recovery-time 0
      set viral-charge 0
      set residence-city idc

      set use-protection 0



      ;; distribution of people by age from French population projection in 2020, T16F032T2 https://www.insee.fr/fr/statistiques/1906664?sommaire=1906743
      let a random-float 100
      ifelse (a < under20) [ set age "under-20"][
        ifelse (a < (under20 + from20to59)) [ set age "20-59"][
        ifelse (a < (under20 + from20to59 + from60to74)) [ set age "60-74"][set age "over-75"]
      ]
      ]


      ;; distribution of active workers by age from French population in 2016, Figure 2 https://www.insee.fr/fr/statistiques/3303384?sommaire=3353488
      ;; nb. age categories are not exactly coincidental (÷- 5 years)
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
        ifelse (c < essential-industry) [set work-status "essential"][set work-status "non-essential"]
      ]


      ;; distribution of households by compostion in France in 2015  https://www.insee.fr/fr/statistiques/3676599?sommaire=3696937
      ; single = 35.3% (48.8% among > 80 years old)
      ; couple no kids = 25.5
      ; couple with kids = 25.5
      ; adult with kids = 8.9
      let d random-float 100
       ifelse [age] of self = "over-75" [
        ifelse (d < elders-alone) [set household-status "alone"][set household-status "couple"]
      ] [
         ifelse (d < alone) [set household-status "alone"][
          ifelse (d < alone + couple) [set household-status "couple"] [set household-status "with-children"]
        ]
      ]



      ;; hard to estimate. proba of caring at 10 initially but will rise with the number of infected.
       let f random-float 100
       ifelse (f < initial-proba-caring-away) [set caring-away-status "care"][set household-status "no-care"]



      ;;source: https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=1&ved=2ahUKEwizuoyypbHoAhWNgVwKHdERDqIQFjAAegQIBBAB&url=https%3A%2F%2Fwww.insee.fr%2Ffr%2Fstatistiques%2Ffichier%2F2586038%2FLOGFRA17j1_F5.1.pdf&usg=AOvVaw1FYYaTUWdRFyhe9mqPV_zI
      ;; 15% of households have another residence

         let g random-float 100
       ifelse (g < proba-secondary-home) [set secondary-home 1][set secondary-home 0]



         ;;source : https://www.insee.fr/fr/statistiques/3620894
      ;; in France 2018 for municipalities with population between 2000 and 100000 residents: 33% collective homes, 66% individual

       let h random-float 100
       ifelse (h < share-collective-housing) [set home-type "collective"][set home-type "individual"]


      ;; hypertension : 10millions = 14% FRance https://www.fedecardio.org/Je-m-informe/Reduire-le-risque-cardio-vasculaire/lhypertension-arterielle
      ;; diabetes : 3.3 millions = 5% FRance https://www.santepubliquefrance.fr/maladies-et-traumatismes/diabete/articles/prevalence-et-incidence-du-diabete
      ;; cancer : entre 2.5 (femmes) et 4 (hommes) cas pour 1000 personnes dans le monde en 2005 https://www.ligue-cancer.net/article/26089_les-chiffres-cles-des-cancers

      ;; if we sum 14 + 5 + 3 = potentially around 22% of people with comorbidity
           let j random-float 100
       ifelse (j < proba-comorbidity) [ set comorbidity 1][set comorbidity 0]



      ;; source: https://www.francetvinfo.fr/sante/maladie/coronavirus/coronavirus-des-francais-bloques-a-letranger_3877017.html
      ;; 130 000 français attendant leur rappatriation = 0.2%
           let k random-float 100
       ifelse (k < repatriated-share) [set repatriated 1][ set repatriated 0]

    ]
  ]
  ask one-of people [set infected? 1]

   assign-color
end

to assign-color
  ask people with [infected? = 0][ set color green ]
  ask people with [infected? = 1][ set color red ]
  ask people with [immune? = 1][ set color blue ]
  ask people with [alive? = 0][ set color black ]
end
@#$#@#$#@
GRAPHICS-WINDOW
218
10
759
552
-1
-1
13.0
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
15
10
81
43
NIL
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
37
112
209
145
max-pop-city
max-pop-city
200
10000
1100.0
100
1
NIL
HORIZONTAL

SLIDER
38
76
210
109
n-cities
n-cities
0
10
9.0
1
1
NIL
HORIZONTAL

SLIDER
767
27
939
60
under20
under20
0
100
24.0
1
1
%
HORIZONTAL

SLIDER
766
60
940
93
from20to59
from20to59
0
100
50.0
1
1
%
HORIZONTAL

SLIDER
768
94
940
127
from60to74
from60to74
0
100
17.0
1
1
%
HORIZONTAL

SLIDER
767
146
939
179
under24-activity
under24-activity
0
100
37.0
1
1
%
HORIZONTAL

SLIDER
766
179
945
212
from25to49-activity
from25to49-activity
0
100
88.0
1
1
NIL
HORIZONTAL

SLIDER
767
212
946
245
from50to64-activity
from50to64-activity
0
100
65.0
1
1
NIL
HORIZONTAL

SLIDER
768
262
940
295
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
768
318
940
351
elders-alone
elders-alone
0
100
49.0
1
1
NIL
HORIZONTAL

SLIDER
769
351
941
384
alone
alone
0
100
35.0
1
1
NIL
HORIZONTAL

SLIDER
768
385
940
418
couple
couple
0
100
26.0
1
1
%
HORIZONTAL

SLIDER
34
180
211
213
initial-proba-caring-away
initial-proba-caring-away
0
100
10.0
1
1
NIL
HORIZONTAL

SLIDER
949
37
1152
70
proba-secondary-home
proba-secondary-home
0
100
15.0
1
1
NIL
HORIZONTAL

SLIDER
947
93
1119
126
repatriated-share
repatriated-share
0
100
0.2
0.1
1
NIL
HORIZONTAL

SLIDER
769
505
941
538
proba-comorbidity
proba-comorbidity
0
100
22.0
1
1
NIL
HORIZONTAL

SLIDER
769
437
979
470
share-collective-housing
share-collective-housing
0
100
33.0
1
1
NIL
HORIZONTAL

TEXTBOX
770
12
920
30
age structure
11
0.0
1

TEXTBOX
770
131
1064
159
activity rate (active vs. inactive/unemployed)
11
0.0
1

TEXTBOX
771
248
1131
290
share of workers in essential industries (healthcare, etc.)
11
0.0
1

TEXTBOX
768
300
918
318
household composition 
11
0.0
1

TEXTBOX
951
20
1208
48
share of households with secondary home
11
0.0
1

TEXTBOX
949
76
1240
104
people potentially repatriated from abroad\n
11
0.0
1

TEXTBOX
770
420
1060
448
share of hosueholds living in collective housing
11
0.0
1

TEXTBOX
768
472
987
514
probability of having comorbidities (heart disease, cancer, diabetes)
11
0.0
1

TEXTBOX
977
182
1127
201
FROM STATISTICS
15
16.0
0

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
