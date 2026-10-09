# Third-party sources

Only these two sources are copied into the app (licences checked at the source on 2026-10-07); the
research behind our own numbers is credited under Research references below.

| What | Where it lives | Taken from | Original source | Licence |
|---|---|---|---|---|
| Exercise database (876 exercises: names, equipment, category, muscle tags) | `data/freeExerciseDb/` (not in our history) | https://github.com/yuhonas/free-exercise-db f00c92c7 (2026-09-27) | restructured from https://github.com/wrkout/exercises.json | both public domain (Unlicense) |
| Body drawings, male + female, front + back | `models/muscleMap/source/` | https://github.com/melihcolpan/MuscleMap 7dc03071 (2026-04-20), MIT, (c) 2026 Melih Colpan | the path data is copied from https://github.com/HichamELBSI/react-native-body-highlighter (assets/body*.ts), MIT, (c) 2022 ELABBASSI Hicham | MIT (both) |

Notes from the check:
- The body drawings: MuscleMap's back views match react-native-body-highlighter number for number, and its
  front views share every distinct coordinate value (MuscleMap adds sub-group detail). MuscleMap does not credit it. So both MIT
  notices apply: keep both copyright lines with anything built from the drawings (our body maps and tap shapes).
  The original author has not confirmed the drawings are their own original artwork (open question on their
  repo, issue #102, unanswered as of 2026-10-07).
- The exercise database: we keep only ids, names, equipment, category and muscle tags (turned into our
  shares) - none of its instructions text or photos. Neither upstream says where the data first came from.

To restore the exercise database on a new machine:
`git clone https://github.com/yuhonas/free-exercise-db.git data/freeExerciseDb` then
`git -C data/freeExerciseDb checkout f00c92c7`.

## Research references

No other dataset is copied into the app. The numbers below were researched by reading the pages listed
(many studies only as their public abstract or a search summary, where the full page blocked reading) and
written in our own words: the muscle shares in `tools/appData/researchedExercises.json`, the target presets
and their key exercises in `tools/appData/targetPresets.json`, and the cardio model in `tools/appData/cardio.json`.
Research round: 2026-10-10.

### Datasets looked at and NOT used

| Dataset | Why not |
|---|---|
| wger exercise data | CC-BY-SA (share-alike would bind our data) and AGPL code |
| ExerciseDB (RapidAPI) | AGPL plus the API's own terms |
| MuscleWiki, ExRx | no licence to reuse; ExRx also blocked reading (403) |
| Everkinetic | CC BY-SA (share-alike) |
| Kaggle exercise sets | origin and licence not verifiable |

### Exercise muscle shares (651 exercises re-checked, 31 machines and moves added)

- [Effect of Five Bench Inclinations on the EMG Activity of the Pectoralis Major, Anterior Deltoid, and Triceps Brachii during the Bench Press](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7579505/) - incline raises upper-pec and front delt, decline and flat favour sternal pec
- [Influence of bench angle on upper extremity muscular activation during bench press exercise](https://pubmed.ncbi.nlm.nih.gov/25799093/) - upper-pec and delt response to bench angle
- [Bench press grip width EMG study (found via search; also PMC5504579)](https://pmc.ncbi.nlm.nih.gov/articles/PMC8296276) - wide grip lowers triceps and front delt, pec similar; read from search summary only
- [A comparison of muscle activation between a Smith machine and free weight bench press](https://pubmed.ncbi.nlm.nih.gov/20093960/) - Smith vs free bench: pec and front delt alike, side delt (stabiliser) lower on Smith
- [ACE study tests common chest exercises](https://www.acefitness.org/about-ace/press-room/press-releases/2930/ace-study-tests-common-chest-exercises-finds-barbell-bench-press-most-effective/) - bench press and cable crossover near top for pec activation, incline fly lower; used to calibrate presses vs flyes
- [Pull over: analysis of muscle activation in all its variations (summarises Marchetti and Uchida 2011 and others)](https://mundoentrenamiento.com/en/pull-over/) - pullover EMG order: pec above triceps above lats
- [Selective Activation of Shoulder, Trunk, and Arm Muscles: A Comparative Analysis of Different Push-Up Variants](https://pubmed.ncbi.nlm.nih.gov/26488636/) - push-up variants: serratus, delt, triceps, core response
- [Marcolin et al. 2015, push-up hand position and muscle activity](https://iris.unipa.it/bitstream/10447/215355/1/MARCOLIN%202015.pdf) - narrow hands raise triceps and pec, wide hands (150 percent width) raise serratus; read from search summary only
- [Journal of Sports Science and Medicine 13:502, suspension vs traditional push-up](https://jssm.org/jssm-13-502.xml-Fulltext) - suspended push-up raises pec, front delt, triceps and core versus floor
- [Push-up on stable surface vs Swiss ball (hands vs feet) EMG study](https://pubmed.ncbi.nlm.nih.gov/32507156/) - feet on ball: pec similar, triceps higher; stable floor gives more front delt
- [Guillotine Press Guide - Muscles Worked](https://fitnessvolt.com/guillotine-press-guide/) - guillotine/neck press leans on upper-pec fibres, front delt and triceps
- [Svend press (also fitbod.me/exercises/svend-press)](https://www.garagegymreviews.com/svend-press) - Svend press and chest squeeze: isometric pec contraction, delt and triceps assist
- [Floor Press vs Bench Press](https://fitnessvolt.com/floor-press-vs-bench-press/) - floor press: pec still prime but range is short so triceps carry more
- [Muscle activity levels in upper-body push exercises with different loads and stability conditions](https://pubmed.ncbi.nlm.nih.gov/25419894/) - pec, delt, triceps response across press and push-up setups
- [Dynamite Delts: ACE Research Identifies Top Shoulder Exercises](https://www.acefitness.org/continuing-education/prosource/research-special-issue-2015/5320/dynamite-delts-ace-research-identifies-top-shoulder-exercises/) - EMG of anterior/middle/posterior deltoid in DB press, rear lateral raise, bent-arm lateral raise, upright row, front raise, cable diagonal raise, push-up, dips, battling ropes (which delt head each exercise loads)
- [ACE-sponsored research: best triceps exercises](https://www.acefitness.org/certifiednewsarticle/1562/ace-sponsored-research-best-triceps-exercises/) - relative triceps long/lateral head EMG: kickback, dips, overhead extension, rope/bar pushdown, lying extension, close-grip bench
- [EMG of pectoralis major portions, anterior deltoid and triceps at different bench inclinations](https://pmc.ncbi.nlm.nih.gov/articles/PMC7579505/) - chest vs front delt vs triceps split in flat/incline pressing; triceps equal across angles
- [High-density surface EMG in front vs back overhead press (J Hum Kinet)](https://jhk.termedia.pl/High-Density-Surface-Electromyography-Excitation-in-Front-vs-Back-Overhead-Press,205466,0,2.html) - behind-the-neck press shifts load to middle/rear delt, front press favours front delt and upper chest (search-result summary)
- [BarBend on overhead triceps extension vs pushdown hypertrophy study](https://barbend.com/overhead-triceps-extensions-vs-pushdowns-muscle-growth-study) - overhead extensions train the triceps incl. long head at least as well as pushdowns (search-result summary)
- [EMG of the shoulder girdle musculature during external rotation exercises](https://pubmed.ncbi.nlm.nih.gov/26740950/) - external rotation loads infraspinatus/teres minor with posterior delt and mid trap/rhomboid help (search-result summary)
- [EMG of shoulder girdle muscles during common internal rotation exercises](https://hira.hope.ac.uk/id/eprint/650/) - internal rotation loads subscapularis with pec/lat help (search-result summary)
- [StrengthLog kettlebell snatch muscles worked](https://www.strengthlog.com/kettlebell-snatch/) - snatch is hip/back driven (glutes, erectors, hamstrings, traps, grip), not a shoulder exercise
- [Fitness Volt: two-arm kettlebell jerk](https://fitnessvolt.com/substitute-exercises/two-arm-kettlebell-jerk-alternatives/) - jerk = front and side delts, triceps, upper traps with leg drive (search-result summary)
- [Activation of selected core muscles: overhead press vs push press](https://lida.sport-iat.de/ta/Record/4038923) - push press adds trunk/erector and leg drive over the strict press (search-result summary)
- [Garage Gym Reviews: JM press](https://garagegymreviews.com/jm-press) - JM press = triceps lateral and long heads with some chest and front delt (search-result summary)
- [Powerlifting Technique: floor press](https://powerliftingtechnique.com/floor-press/) - floor press shortens range so triceps lockout work rises, chest stretch lost (search-result summary)
- [EMG comparison of traditional, hammer and reverse biceps curls](https://pmc.ncbi.nlm.nih.gov/articles/PMC6047503) - biceps highest in supinated curl, brachialis/brachioradialis higher in hammer and reverse curls
- [High-density EMG excitation in front vs back lat pull-down prime movers](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11057623/) - front pulldown gives more pec/lat excitation overall, behind-the-neck shifts load toward upper back/traps
- [Electromyographic analysis of three different types of lat pull-down](https://pubmed.ncbi.nlm.nih.gov/19855327/) - pulldown grip/bar variants: lat activation similar, pec higher in front pulldown, trapezius higher behind the neck
- [Electromyographic activity in deadlift exercise and its variants. A systematic review](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7046193/) - erector spinae and quads highest in deadlift, glutes/hamstrings next, traps and lats as stabilisers
- [Surface EMG analysis of exercises for the trapezius and serratus anterior](https://pubmed.ncbi.nlm.nih.gov/12774999/) - trapezius fibre activation across shrugs, rows, raises; lower/mid trap work in pulls
- [Muscle activation during selected strength exercises in women with chronic neck muscle pain](https://test01.ku.dk/:obvius/pureproxy/3974268/en/publications/muscle-activation-during-selected-strength-exercises-in-women-wit) - shrug highest upper trap activation (~100% MVC), upright row and lateral raise close behind
- [Electromyographic analysis of the back muscles during various back exercises (thesis)](https://minds.wisconsin.edu/handle/1793/76924) - bent-over/seated/inverted row mid-trap and lat activation, pull-up/chin-up lat activation, I-Y-T for lower trap
- [Fenwick 2009, Comparison of different rowing exercises (JSCR)](https://www.backfitpro.com/medical-scientific-articles/2009/[80]Fenwick,C.M.J.(2009)Comparison-of-different-rowing-exercises[J.Strength-and-Cond.].pdf) - inverted row gives high lat/upper-back/hip-extensor activation with lower lumbar erector load than bent-over barbell row
- [EMG for pull-up grip modifications (EKU poster)](https://encompass.eku.edu/swps/2019/graduate/7) - pronated grips higher lat than supinated, pull-up more lower trap, chin-up more biceps
- [ACE study reveals best biceps exercises](https://www.acefitness.org/continuing-education/prosource/research-special-issue-2015/5319/ace-study-reveals-best-biceps-exercises/) - concentration curl highest biceps; preacher/incline lower brachioradialis and front delt than barbell curl
- [Comparison of muscle activity during a ring muscle-up and bar muscle-up](https://digitalcommons.wku.edu/ijesab/vol11/iss5/28/) - muscle-up recruits upper/lower trap, serratus, pec major, lats, triceps, biceps and forearm flexors
- [EMG of weightlifting derivatives (hang clean/snatch and pulls), JSSM](https://jssm.org/jssm-22-778.xml-abst) - trapezius, glutes, quads high in pulls; erector/abs as stabilisers; vastus lateralis, glute max and trapezius all strongly active in weightlifting derivatives; pull and catch similar
- [Forearm EMG and wrist flexor/extensor training (Health and Behavior Sciences 2010)](https://www.jstage.jst.go.jp/article/hbs/8/2/8_51/_article/-char/en) - wrist flexors and extensors co-contract in wrist work and gripping
- [Rack pull vs deadlift](https://fitnessvolt.com/rack-pull-vs-deadlift/) - rack pull shifts work to upper back/erectors and away from quads/hamstrings
- [EMG comparison of back squat variations (full, parallel, sumo, front squat) at 80% 1RM](https://pmc.ncbi.nlm.nih.gov/articles/PMC7831128/) - sumo stance raises vastus lateralis, front squat raises rectus femoris, vastus medialis highly active in all squats
- [Contreras et al. 2015: gluteus maximus and hamstring EMG in hip thrust vs back squat](https://www.bisp-surf.de/Record/PU201606003683) - hip thrust gives far higher glute max and biceps femoris activity than squat; quad (vastus lateralis) similar
- [Hip thrust and back squat training elicit similar gluteus hypertrophy (Frontiers in Physiology 2023)](https://www.frontiersin.org/journals/physiology/articles/10.3389/fphys.2023.1279170/pdf) - squat keeps quads and glutes both working; hip thrust is glute-led
- [Nordic hamstring exercise vs razor hamstring curl EMG](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10723670/) - Nordic style curls load semitendinosus, biceps femoris and calf (gastrocnemius) together
- [McAllister et al. 2014: muscle activation during various hamstring exercises](https://oliverfinlay.com/assets/pdf/mcallister et al (2014) muscle activation during various hamstring exercises.pdf) - glute-ham raise and Romanian deadlift give the highest hamstring activity; read through a search summary because the PDF text could not be fetched
- [Standing (straight-knee) vs seated (bent-knee) calf raise hypertrophy (Frontiers in Physiology 2023)](https://www.frontiersin.org/journals/physiology/articles/10.3389/fphys.2023.1272106/pdf) - both calf raise types train calves; standing hits gastrocnemius, seated hits soleus (our calves region covers both)
- [Seated vs lying leg curl article summarising Maeo et al. 2021](https://muscleevo.net/seated-vs-lying-leg-curl/) - leg curls train the hamstrings; seated version loads them longer, so biggest growth
- [Electromyographical comparison of muscle activation across kettlebell exercises](https://pmc.ncbi.nlm.nih.gov/articles/PMC4637916/) - kettlebell swing/clean: glutes and biceps femoris high, erector spinae strong, quads moderate
- [Optimizing hip abductor strengthening: monster walk and lateral band walk (narrative review)](https://pmc.ncbi.nlm.nih.gov/articles/PMC12372021/) - band walks load gluteus medius and glute max moderately to highly, best in a semi-squat with band at the feet
- [Best exercises for gluteus maximus and medius (summary of Distefano 2009)](https://mikereinold.com/best-exercises-for-gluteus-maximus-and/) - side-lying abduction highest medius, single-leg squat next, band walk third
- [EMG of glute med/max, biceps femoris and quads in monopodal squat, forward lunge and lateral step-up](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7112217/) - single-leg work loads vasti highest then gluteus medius; monopodal squat highest overall
- [EMG of split squat, single-leg squat and rear-foot-elevated split squat](https://nih.brage.unit.no/nih-xmlui/handle/11250/2602541?show=full) - glute max and vastus lateralis similar across split squat types; gluteus medius far higher in single-leg squat
- [Sled push muscles worked (Strengthlog) plus a JHSE sled-load kinematics study found in the same search](https://www.strengthlog.com/?p=37047) - sled work is quad-led with strong glute and calf involvement, quads rise most as load goes up
- [Effects of load on good morning kinematics and EMG activity](https://peerj.com/articles/708) - good morning loads erector spinae most, then hamstrings, rising with load; glutes do hip extension
- [Biomechanical analysis of conventional and sumo deadlift](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12148905/) - sumo raises vasti and tibialis activity, conventional raises medial gastroc; adductors strongly active in both
- [EMG differences between hyperextension and reverse hyperextension](https://ouci.dntb.gov.ua/works/4OODpeb4) - reverse hyper gives higher erector, glute max and biceps femoris activity than back extension
- [Ebben 2009: muscle activation during lower body resistance training](https://pubmed.ncbi.nlm.nih.gov/18975260/) - general ranking of quad, hamstring and glute activity across squat, lunge, leg press, deadlift and jumps; also used loosely for plyometric rows
- [Serner et al. 2014: EMG evaluation of hip adduction exercises](https://bjsm.bmj.com/content/48/14/1108) - adductor longus activity across adduction exercises (band, ball squeeze, Copenhagen); confirms adductors as sole prime mover
- [Muscle activity of quadriceps and hamstrings across squat variations](https://pmc.ncbi.nlm.nih.gov/articles/PMC8783452) - squat type changes the quad split slightly; quads always dominant, hamstrings low
- [Escamilla et al. 2006, EMG analysis of traditional and nontraditional abdominal exercises (Physical Therapy)](https://scholars.csus.edu/esploro/outputs/journalArticle/Electromyographic-Analysis-of-Traditional-and-Nontraditional/99257847129401671) - which exercises load rectus abdominis, obliques and rectus femoris most (power wheel roll-out, hanging knee-up, inclined reverse crunch highest vs crunch); rectus femoris caution
- [EMG comparison of a variety of abdominal exercises to the traditional crunch (University of Wisconsin repository)](https://minds.wisc.edu/items/13f23340-bc92-4049-9c47-6fcc60df9852) - ab wheel, planks and side plank gave lower upper/lower rectus activity than a crunch; no exercise beat the crunch for rectus
- [Willett et al. 2001, relative activity of abdominal muscles during commonly prescribed strengthening exercises (JSCR)](https://busqueda.bvsalud.org/portal/resource/es/mdl-11726260) - reverse curl-up gives most lower rectus work, v-sit and reverse curl most external oblique, trunk curl and reverse curl similar upper rectus
- [Anti-rotational and rotational abdominal exercises and concurrent muscle activation (Western Kentucky Univ., IJESAB)](https://digitalcommons.wku.edu/ijesab/vol8/iss9/12) - Pallof-type and rotational cable work loads the internal/external obliques with erector spinae assisting
- [Multidirectional neck strength and EMG activity for normal controls (Clinical Biomechanics)](https://experts.umn.edu/en/publications/multidirectional-neck-strength-and-electromyographic-activity-for) - neck flexion mostly sternocleidomastoid, extension splenius and upper trapezius contribute
- [StrengthLog, machine glute kickback](https://www.strengthlog.com/machine-glute-kickbacks/) - glutes primary, hamstrings and adductors secondary for the machine kickback
- [Frontiers in Physiology 2025, dumbbell vs cable lateral raise and lateral deltoid growth](https://www.frontiersin.org/journals/physiology/articles/10.3389/fphys.2025.1611468/full) - cable/machine lateral raise grows the lateral deltoid as well as dumbbells, so same side-delt share
- [Pendulum squat vs hack squat articles (search summary only, page itself returned 403)](https://powerliftingtechnique.com/pendulum-squat/) - pendulum squat quad-dominant with glutes more active than a hack squat

### Target presets and their key exercises

**Marathon** (confidence: medium)

- [Heavy Resistance Training Versus Plyometric Training for Improving Running Economy and Running Time Trial Performance: A Systematic Review and Meta-analysis](https://pmc.ncbi.nlm.nih.gov/articles/PMC9653533/) - heavy lifting (near 90% 1RM, 10+ weeks) improves running economy and time trial more than plyometrics; supports short heavy sessions
- [Blagrove et al. 2018, Effects of strength training on the physiological determinants of middle- and long-distance running performance (Sports Medicine)](https://repository.lboro.ac.uk/articles/journal_contribution/Effects_of_strength_training_on_the_physiological_determinants_of_middle-_and_long-distance_running_performance_a_systematic_review/9619553) - 2-3 strength sessions per week recommended; running economy gains of 2-8% in most studies
- [Lauersen et al. 2014, The effectiveness of exercise interventions to prevent sports injuries (BJSM meta-analysis)](https://bjsm.bmj.com/content/48/11/871) - strength training cuts overuse injuries by about half across sports; justifies the injury-resilience muscles
- [Barbell Medicine, a case for training calves](https://www.barbellmedicine.com/blog/a-case-for-training-calves/) - soleus as main force producer in running; runners with Achilles tendinopathy show much lower plantarflexor strength; 1-2 calf sessions of 2-3 sets, knee-straight and knee-bent versions
- [The outcome of hip exercise in patellofemoral pain: A systematic review](https://research.brighton.ac.uk/en/publications/7cc34ef5-58c4-45ea-818b-0f9e4eb1794e) - hip strengthening (abductors and external rotators) helps knee pain; weak hip abductors and late gluteus medius activation are associated with running knee problems
- [Quantitative analysis of 92 sub-elite marathon training plans](https://pmc.ncbi.nlm.nih.gov/articles/PMC11065819/) - weekly volumes (about 43-108 km), long run length, and how plans distribute time across intensity zones
- [Does polarized training improve performance in recreational runners? (Esteve-Lanao and colleagues)](https://pubmed.ncbi.nlm.nih.gov/23752040/) - recreational runners improved more with ~77% easy / 3% middle / 20% hard than with a threshold-heavy split; easy-dominant shape for the cardio split (I read only the search summary of this page)
- [Sports Medicine - Open version of the heavy resistance vs plyometric review](https://sportsmedicine-open.springeropen.com/articles/10.1186/s40798-022-00511-1) - cross-check of the same meta-analysis numbers (g = -0.32 heavy vs -0.13 plyometric on running economy)

**Sprinting** (confidence: medium)

- [The Effects of Nordic Hamstring Exercise on Performance and Injury in the Lower Extremities: An Umbrella Review](https://pmc.ncbi.nlm.nih.gov/articles/PMC11311354/) - Nordic injury reduction (up to ~51%, risk ratio 0.49), dose (2-3 sets of 6-12, about 48 reps/week), small sprint gains
- [The Training and Development of Elite Sprint Performance: an Integration of Scientific and Best Practice Literature (Haugen, Seiler et al. 2019)](https://pmc.ncbi.nlm.nih.gov/articles/PMC6872694/) - 2-3 sprint sessions and 2-3 gym sessions a week, 48 h between sprint days, sprint and tempo run volumes, 4-6 week strength cycles
- [The Science and Best Practice of Training Elite Sprinters (1080 Motion summary)](https://www.1080motion.com/news/the-science-and-best-practice-of-training-elite-sprinters) - session meters (acceleration 100-300 m, max velocity 50-150 m, tempo 1000-2000 m) and long rests used to count honest cardio minutes
- [Acute hamstring strain injury in track-and-field athletes: a 3-year observational study at the Penn Relay Carnival (Opar et al. 2014)](https://acuresearchbank.acu.edu.au/item/85751/acute-hamstring-strain-injury-in-track-and-field-athletes-a-3-year-observational-study-at-the-penn-relay-carnival) - hamstring strain is the dominant sprint injury, mostly at near-max speed; higher in 400 m than 100 m
- [Muscular strategy shift in human running: dependence of running speed on hip and ankle muscle performance (Dorn, Schache, Pandy 2012)](https://pubmed.ncbi.nlm.nih.gov/22573774/) - ankle plantarflexors dominate up to ~7 m/s, hip muscles (iliopsoas, glutes, hamstrings) take over at sprint speeds (read via search summary, page itself blocked)
- [Thigh and psoas major muscularity and its relation to running mechanics in sprinters](https://lida.sport-iat.de/dlv/Record/4050802) - sprinters have larger hip flexor, psoas major and adductor volumes (abstract only)
- [Hip Torque Is a Mechanistic Link Between Sprint Acceleration and Maximum Velocity Performance: A Theoretical Perspective](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9314550/) - thigh angular acceleration and hip torque as a speed limiter, supporting hip flexor and hip extensor emphasis (abstract only)
- [Built for speed: musculoskeletal structure and sprinting ability (Lee and Piazza 2009)](https://pure.psu.edu/en/publications/built-for-speed-musculoskeletal-structure-and-sprinting-ability/) - plantarflexor and foot structure in sprinters supports calf and Achilles emphasis (abstract only)

**Basketball** (confidence: medium)

- [Time-motion analysis and physiological data of elite under-19-year-old basketball players during competition (Ben Abdelkrim et al., BJSM 2007)](https://pmc.ncbi.nlm.nih.gov/articles/PMC2658931) - Mean heart rate about 91 percent of max, lactate about 5.5 mmol/l, about 1,050 movements per game, 16 percent of live time high intensity (sprints, jumps, specific moves)
- [Injury in the National Basketball Association: a 17-year overview (Drakos et al.)](https://vivo.weill.cornell.edu/display/pubid23015949) - Ankle sprain most frequent (13.2 percent), patellofemoral inflammation most games missed (17.5 percent), lumbar and hamstring strains
- [Sure Steps: Key Strategies for Protecting Basketball Players from Injuries - a systematic review (seen via search summary, page itself blocked)](https://pmc.ncbi.nlm.nih.gov/articles/PMC11355145) - Ankle and knee dominate; combined neuromuscular training best; risk factors include weak hip abduction, poor balance, limited ankle dorsiflexion
- [How important is strength training for basketball players? (Cabarkapa)](https://journals.lib.pte.hu/index.php/seef/article/view/8709) - Upper and lower body strength linked to playing time, change of direction and shooting; periodized strength work all season
- [Effects of plyometric training volume on physical performance in youth basketball players](https://zaguan.unizar.es/record/144751) - Low-volume plyometrics (about 50 jumps a session, twice a week) improved jumping as much as double the volume
- [Nordic hamstring exercise injury prevention meta-analysis (BJSM 2019, seen via search summary)](https://bjsm.bmj.com/content/53/21/1362) - Programs with Nordic curls cut hamstring injury about 51 percent in team sports; Copenhagen adductor evidence is weaker and mixed
- [Hand and wrist injuries among collegiate athletes vary with athlete division (seen via search summary)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8670021/) - Hand and wrist injuries mostly in competition and in guards; forearms kept at baseline rather than raised
- [External Physical Demands during Official Under-18 Basketball Games (seen via search summary, page blocked)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11571470/) - Demands highest in the first quarter and for guards; many accelerations, decelerations and jumps per game

**Football (soccer)** (confidence: medium)

- [Lower extremity muscle injuries in sport: evidence-based statement (BJSM 2020)](https://pmc.ncbi.nlm.nih.gov/articles/PMC7212929) - Risk reductions: Nordics about 65% hamstring, FIFA 11+ about 61% hamstring and 42% groin, Copenhagen programme 41% groin
- [The Adductor Strengthening Programme prevents groin problems among male football players (Harøy et al., cluster RCT)](https://bjsm.bmj.com/content/53/3/150.abstract) - Copenhagen adduction dose: 3x/week pre-season, 1x/week in season, 41% lower groin problem risk
- [Nordic hamstring exercise volume in soccer players: systematic review and meta-analysis (Frontiers in Physiology 2025)](https://www.frontiersin.org/journals/physiology/articles/10.3389/fphys.2025.1631205/full) - Higher-volume Nordics (2-3 sets of 8-12, 2-3x per week) improve strength and fascicle length more than low volume
- [Acute hamstring injury prevention programs in eleven-a-side football players: systematic review](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8125962/) - Programmes including Nordics reduce hamstring injuries; FIFA 11+ effective for injuries and strength
- [Physiological demands of football (Sports Science Exchange 125)](https://www.gssiweb.org/sports-science-exchange/article/sse-125-physiological-demands-of-football) - Match demands: 10-13 km, about 85% average HRmax, about 70% VO2max, 150-250 intense actions, position differences
- [Physical and metabolic demands of training and match-play in the elite football player (Bangsbo, Mohr, Krustrup 2006)](https://test01.ku.dk/:obvius/pureproxy/3974268/en/publications/physical-and-metabolic-demands-of-training-and-match-play-in-the-) - Intermittent profile, glycolytic and sprint demand, late-game fatigue
- [Strength training in soccer with a specific focus on highly trained players (Silva et al., Sports Medicine Open 2015)](https://sportsmedicine-open.springeropen.com/track/pdf/10.1186/s40798-015-0006-z) - Lower-body strength work supports sprint, jump and in-season performance; concurrent training with endurance
- [Recreational football as a health-promoting activity (Krustrup et al.)](https://pmc.ncbi.nlm.nih.gov/articles/PMC4413738) - Small-sided training intensity of about 80% HRmax and typical 1.5-2 sessions a week for amateurs

**Swimming** (confidence: medium)

- [Effectiveness of Therapeutic Exercise in Musculoskeletal Risk Factors Related to Swimmer's Shoulder (systematic review, 2022)](https://pubmed.ncbi.nlm.nih.gov/35735465/) - 6-8 week programmes of external rotator and scapular retractor strengthening plus pec stretching cut shoulder pain; prevalence 40-91%, 20-35% lose time (read via search summary, page itself blocked)
- [The prevention of the most common shoulder injuries in competitive swimming: a narrative literature review](https://www.theseus.fi/handle/10024/876021) - rotator cuff strengthening combined with core training is the most recommended prevention approach (search summary)
- [The Complete Guide to Preventing Swimmer's Shoulder](https://ctyeh.com/articles/2238?lang=en) - risk factors (volume, IR/ER imbalance, scapular stability) and a practical dose: ER band 3x15, Y-T-W 3x10, serratus plus 3x12, 4-5 times a week
- [Training intensity distribution, training volume, and periodization models in elite swimmers: a systematic review](https://lida.sport-iat.de/ta/Record/4072108) - sprinters polarized/threshold, middle distance threshold/pyramidal, distance pyramidal; ~86-90% of swum volume at or under 4 mmol lactate
- [Editorial: Training Intensity, Volume and Recovery Distribution Among Elite and Recreational Endurance Athletes](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6537749/) - the three-zone definition of intensity distribution
- [USMS forum: average weekly training (masters swimmers)](https://community.usms.org/swimming/f/general/1666/average-weekly-training) - typical masters volume 9-15k yards a week, 3-5 sessions of about an hour (anecdotal, low weight)
- [USMS forum: how much does a good kick contribute](https://community.usms.org/swimming/f/general/5906/how-much-does-a-good-kick-contribute) - legs give roughly 10-15% of propulsion, justifying low gym leg volume (anecdotal, low weight)
- [NSCA Coach: Beyond the Pool - Improving Swimming Performance with Dryland Training](https://dxpprod.nsca.com/education/articles/nsca-coach/beyond-the-pool-improving-swimming-performance-with-dryland-training/) - dryland emphasis on lats, shoulders, triceps, core stability and injury prevention (page blocked; used via search snippet only)

**Cycling** (confidence: medium)

- [Optimizing strength training for running and cycling endurance performance: a review (Ronnestad and Mujika, 2014)](https://www.inigomujika.com/en/2013/08/13/optimizing-strength-training-for-running-and-cycling-endurance-performance-a-review-2/3040/) - heavy strength training is the type with the most solid added benefit on cycling economy and performance
- [Does Maximal Strength Training Improve Endurance Performance in Highly Trained Cyclists: A Systematic Review](https://openrepository.aut.ac.nz/handle/10292/10745) - gains in economy, efficiency and time-trial power; half-squat 4x4 at ~4 reps max, 3 times a week study (4.8% economy gain)
- [Strength training for cyclists: complete guide (Roadman Cycling)](https://roadmancycling.com/blog/strength-training-cyclists-complete-guide) - practical split: 2 non-consecutive sessions, 2-3 sets per pattern, at least 80% 1RM, plus upper body and trunk patterns; the 2025 meta-analysis summary was relayed via a search result
- [Cycling and bone health: a systematic review (Olmedillas et al., 2012)](https://pmc.ncbi.nlm.nih.gov/articles/PMC3554602/) - road cyclists have lower lumbar spine, pelvis and hip bone density; two thirds osteopenic; recommend impact or loaded training
- [Stephen Seiler on 80/20 polarised training for cyclists (Roadman Cycling)](https://roadmancycling.com/blog/stephen-seiler-80-20-polarised-training-cyclists) - about 80% of time easy, 20% hard, two hard sessions a week, one long ride of 2.5-4 hours, for 8-14 hour weeks
- [Polarised training cycling guide (Roadman Cycling)](https://roadmancycling.com/blog/polarised-training-cycling-guide) - example weekly hours by zone for 8 and 12 hour weeks; high-intensity time capped near 1 hour a week
- [Cycling overuse injuries / low back pain in cyclists (via search result; page itself was not opened)](https://pmc.ncbi.nlm.nih.gov/articles/PMC5315261) - low back pain in over half of riders, neck pain in about half, trunk muscle imbalance and back-extensor endurance deficits (from the search summary only)

**Climbing** (confidence: medium)

- [Regional Body Composition and Strength, Not Total Body Composition, Are Determinants of Performance in Climbers](https://pmc.ncbi.nlm.nih.gov/articles/PMC11587076/) - forearm lean mass and upper-body pulling strength separate elite from intermediate climbers; total muscle mass does not
- [Cardiorespiratory demands of competitive rock climbing](https://pubmed.ncbi.nlm.nih.gov/32813982/) - bouldering peak about 75% of treadmill VO2max, about 88% of max HR, about 23% of time above gas-exchange threshold, fast recovery
- [Metabolic response during sport rock climbing and the effects of active versus passive recovery](https://pubmed.ncbi.nlm.nih.gov/10834350/) - sport climbing energy demand and why recovery rests matter; context for low z3 time
- [Current Sports Medicine Reports (climbing injuries, Leeds Beckett)](https://eprints.leedsbeckett.ac.uk/id/eprint/3076/3/Current%20Sports%20Medicine%20Reports.pdf) - injury sites (fingers, elbows, shoulders), pull-versus-push imbalance, antagonist training advice
- [Incidence, diagnosis, and management of injury in sport climbing and bouldering: a critical review](https://eprints.leedsbeckett.ac.uk/id/eprint/5197/1/IncidenceDiagnosisandManagementofInjuryinSportClimbing_includingTablesAM-JONES.pdf) - about 70% upper limb injuries, medial epicondylopathy most common elbow problem, shoulder issues linked to imbalance
- [Antagonist-Muscle Training to Prevent Injury (Nicros)](https://nicros.com/training/training-articles/physical/antagonist-muscle-training-to-prevent-injury/) - practical volume: about 2 sessions a week of push-ups, dips, presses, reverse wrist curls and cuff rotations
- [Electric activity of lumbar muscles in sport climbers](https://apcz.umk.pl/JEHS/article/view/4447) - rectus abdominis and erector spinae differences between professional and amateur climbers; trunk role in climbing
- [18-Week Free Climbing Training Program (Beginner/Intermediate)](https://climbinghouse.com/18-week-free-training-program/) - typical amateur week: 2-3 gym sessions plus outdoor days; basis for the cardio minutes with easy aerobic climbing blocks
- [Research Discussion: Eva Lopez-Rivera Finger Strength (Lattice Training)](https://latticetraining.com/blog/research-discussion-eva-lopez-rivera-finger-strength) - finger strength as the key limiter and hangs on edges as the way to train it

**Boxing / MMA** (confidence: medium)

- [Cervical strengthening and concussion incidence in collegiate athletes (NeckX, 12 weeks)](https://pmc.ncbi.nlm.nih.gov/articles/PMC11370701) - neck training dose (3 sessions per week, about 10 min), reduced head and neck injury incidence, and the 5 percent per pound concussion-odds figure it cites
- [Cardio-respiratory endurance responses following a simulated 3 x 3 min amateur boxing contest in elite boxers](https://pmc.ncbi.nlm.nih.gov/articles/PMC6315673) - heart rate at 90 percent or more of max and VO2 above 90 percent of max in every round, lactate 9 to 12 mmol/L after bouts, so round work counts as zone 3
- [Effects of strength training on physical fitness of Olympic combat sports athletes: a systematic review](https://pmc.ncbi.nlm.nih.gov/articles/PMC9961120/) - typical programme dose (2-3 sessions per week, 8-13 weeks), compound lifts at 70-90 percent 1RM, strength gains transfer to boxing and judo actions
- [Injury reduction in combat sports: the role of strength and conditioning](https://www.sportsinjurybulletin.com/diagnose--treat/injury-reduction-in-combat-sports-the-role-of-sc) - lower-limb strength (squat, lunge, step-up), trunk control and joint-specific strengthening as the injury-prevention core
- [Electromyographic and kinematic trunk analysis during the straight punch](https://lida.sport-iat.de/ta/Record/4017632) - skilled boxers rotate the whole trunk and show different internal oblique activity than novices (abstract-level reading)
- [Biomechanical characterization of the Junzuki karate punch: indexes of performance](https://research.uniroma1.it/en/node/48236) - punch force related to leg force and knee action, upper limb muscles dominate co-activation, supporting hip and leg drive (karate, abstract-level reading)
- [Is the handgrip strength performance better in judokas than in non-judokas?](https://lida.sport-iat.de/ta/Record/4025325) - judokas are no stronger in peak grip but resist grip fatigue better, so train grip endurance (abstract-level reading)
- [Prevalence of sport injuries in Olympic combat sports (epidemiology)](https://bjsm.bmj.com/content/52/1/8) - injury sites: head/face, wrist and low back in boxing; shoulder in judo and wrestling (search-snippet level reading)
- [The subtle art of grip strength (BJJ coaching site)](https://eastonbjj.com/brazilian-jiu-jitsu/grip-strength-bjj/) - practical grip tools only (dead hangs, farmer carries, towel grips); no volume numbers or evidence were given, so it did not set any offset size
- [Effects of specific training programs on punch performance (Pinto et al., 2026)](https://shura.shu.ac.uk/37481/) - 8-week trial in trained boxers where a rotation-focused programme gave the biggest gains in punch impact, especially hooks; basis for medicine ball throws and landmine rotations (abstract-level reading)
- [Building a stronger neck: guide for combat athletes](https://getphysical.com/blog/building-stronger-neck-combat-athletes-guide) - practical neck programming (all four directions, short isometrics, harness sets of 10-20); coaching source, not a trial
- [Copenhagen adduction exercise research (search-snippet level)](https://pmc.ncbi.nlm.nih.gov/articles/PMC8486394) - the exercise clearly builds adductor strength but injury-prevention evidence is mixed and low quality, so it is a supporting pick, not a headline one

**V-taper** (confidence: medium)

- [Schoenfeld et al. 2017 - Dose-response relationship between weekly resistance training volume and increases in muscle mass](https://researchgate.net/profile/Brad-Schoenfeld/publication/305455324_Dose-response_relationship_between_weekly_resistance_training_volume_and_increases_in_muscle_mass_A_systematic_review_and_meta-analysis/links/59dc0269458515e9ab4527d6/Dose-response-relationship-between-weekly-resistance-training-volume-and-increases-in-muscle-mass-A-systematic-review-and-meta-analysis.pdf) - Growth rises with weekly sets, about 0.37% per extra set, with more growth at 10+ sets per muscle per week (read via search summary, full text not opened)
- [Set for Set - how many sets to build muscle (summary of Pelland et al. meta-regression, 67 studies)](https://www.setforset.com/blogs/news/how-many-sets-to-build-muscle) - Efficiency tiers: 5-10 sets most efficient, 11-18 still good, 19+ progressively smaller gains; indirect sets count about half
- [Pelland et al. 2024 - Resistance training volume and frequency dose-response meta-regression (SportRxiv preprint)](https://sportrxiv.org/index.php/server/preprint/download/460/967/908) - Square-root hypertrophy curve and half credit for indirect sets (confirmed via search snippet; the PDF itself would not parse)
- [Stronger By Science - research spotlight: muscle growth](https://www.strongerbyscience.com/research-spotlight-muscle-growth/) - Caveat that 12, 18 and 24 weekly quad sets gave similar growth in trained men, so very high volume is not required
- [Bony to Beastly - maintenance training volume (discusses Bickel et al. 2011)](https://bonytobeastly.com/maintenance-training-volume/) - Muscle held for 32 weeks on a small fraction of build volume; roughly 2-5 sets per muscle per week to maintain, basis for the leg maintenance offsets
- [Coachway - Dr Mike Israetel on how many sets (volume landmarks)](https://coachway.io/articles/dr-mike-israetel-how-many-sets-for-coaches/) - Coaching ranges: side delts about 8 sets minimum up to 16-22 optimal, chest and back ranges, rear delts 8-12; used for the side delt and lat targets (secondary, coaching source rather than trial)
- [The Sport Journal - Optimizing development of the pectoralis major](https://thesportjournal.org/article/optimizing-development-of-the-pectoralis-major/) - Upper (clavicular) chest is activated most on a modest incline (roughly 30-45 degrees), supporting a dedicated upper chest bump
- [Bull et al. 2020 - World Health Organization 2020 guidelines on physical activity and sedentary behaviour](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7719906/) - Cardio target: 150-300 min moderate or 75-150 min vigorous per week plus regular muscle strengthening (confirmed via search summary)

**mew2** (confidence: medium)

- [Mewtwo (Wikipedia)](https://en.wikipedia.org/wiki/Mewtwo) - Design origin (Ken Sugimori), 2 m bipedal feline build, large thighs, pronounced tail and collarbone
- [Mewtwo (SmashWiki)](https://ssbwiki.com/Mewtwo) - Second description of the proportions: slim limbs and torso with a heavy tail and legs
- [Stronger By Science, training volume and hypertrophy](https://www.strongerbyscience.com/?p=56687) - Summary of Schoenfeld 2017 meta-analysis: 10+ weekly sets beat 5-9, which beat under 5
- [Pelland et al., resistance training volume and frequency meta-regression](https://sportrxiv.org/index.php/server/preprint/download/460/967/908) - Hypertrophy follows a square-root dose-response, so returns fade but continue past 12 sets/week
- [Maeo et al. 2021, hamstring training at long vs short muscle length](https://pmc.ncbi.nlm.nih.gov/articles/PMC7969179/) - Hip-flexed knee flexion (long muscle length) grew the hamstrings more than short-length training
- [Sci-Sport, seated vs prone leg curl](https://sci-sport.com/en/hypertrophy-and-hamstring-protection-seated-prone-leg-curl/) - Seated leg curl beat prone leg curl for hamstring growth
- [StrengthLog, RDL vs squat vs hip thrust muscle activity](https://www.strengthlog.com/romanian-deadlift-vs-squat-vs-hip-thrust-comparison-of-muscle-activity/) - Hip thrust tops glute and hamstring activation; squat tops quads; squat and deep hip flexion favour adductors
- [WHO 2020 guidelines on physical activity and sedentary behaviour](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7719906/) - General-health cardio: 150-300 min moderate or 75-150 min vigorous per week, plus regular strength work
- [Stronger By Science, squats and adductors](https://www.strongerbyscience.com/squats-adductors/) - Deep squat growth of adductors (Kubo 2019: full squat beat half squat); the adductor machine is a supplement
- [StrengthLog, squats vs leg extensions for quad growth](https://www.strengthlog.com/squat-vs-leg-extension/) - Leg extensions add quad, especially rectus femoris, growth alongside squats

**Hourglass** (confidence: medium)

- [Schoenfeld, Ogborn, Krieger 2017 - Dose-response between weekly resistance training volume and muscle mass (meta-analysis)](https://paulogentil.com/pdf/Dose-response%20relationship%20between%20weekly%20resistance%20training%20volume%20and%20increases%20in%20muscle%20mass%20-%20A%20systematic%20review%20and%20metaanalysis.pdf) - more weekly sets per muscle keeps giving more growth, so emphasised muscles get above-baseline volume
- [Schoenfeld et al. 2019 - Resistance training volume enhances muscle hypertrophy in trained men (6-9 vs 18-27 vs 30-45 sets/week)](https://pmc.ncbi.nlm.nih.gov/articles/PMC6303131/) - higher weekly set volume produced larger thigh and arm gains in 8 weeks; caveats on duration and population
- [Pelland et al. 2024 - Volume and frequency meta-regression for strength and hypertrophy](https://sportrxiv.org/index.php/server/preprint/view/537) - diminishing but positive returns for hypertrophy as sets rise; fractional set counting of indirect sets at 0.5
- [Hip thrust vs back squat, set-volume equated, 9 weeks (Frontiers in Physiology 2023, Contreras co-author)](https://pmc.ncbi.nlm.nih.gov/articles/PMC10593473/) - glute max grew similarly with either lift; glute med/min and hamstrings grew little; squat grew quads and adductors more
- [Renaissance Periodization - glute training guide](https://rpstrength.com/expert-advice/glute-training-tips-hypertrophy) - practical glute volume landmarks (about 6-8 minimum, 8-24 productive, 24-30 upper limit) and lunges for glute med
- [Seated vs prone leg curl hamstring hypertrophy study (Maeo et al.)](https://pmc.ncbi.nlm.nih.gov/articles/PMC7969179/) - hamstrings need direct hip-flexed or lengthened work to grow; seated curl 14.1% vs prone 9.3% growth
- [Review of gluteus maximus and medius activation in exercises (EMG)](https://pmc.ncbi.nlm.nih.gov/articles/PMC4595911/) - glute med is best loaded by single-leg and abduction-type work, not by bilateral lifts alone
- [WHO 2020 guidelines on physical activity and sedentary behaviour](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7719906/) - 150-300 min moderate or 75-150 min vigorous aerobic activity per week for general health, plus regular strength work

### Cardio model (easy and hard cardio, efforts, the weekly default)

- [Bull et al. 2020, World Health Organization 2020 guidelines on physical activity and sedentary behaviour, Br J Sports Med](https://digibug.ugr.es/handle/10481/66573) - 150-300 min moderate / 75-150 vigorous or an equal mix; moderate 5-6 and vigorous 7-8 on a 0-10 scale; muscle strengthening separate; any amount counts
- [CDC, How to Measure Physical Activity Intensity](https://www.cdc.gov/physical-activity-basics/measuring/index.html) - talk test wording for moderate vs vigorous; examples of moderate and vigorous activities
- [CDC, Physical Activity Guidelines for Adults (PAG 2nd ed.)](https://www.cdc.gov/physical-activity-basics/guidelines/adults.html) - one vigorous minute counts about two moderate minutes; strength as a separate recommendation
- [Garber et al. 2011, ACSM Position Stand: Quantity and quality of exercise, Med Sci Sports Exerc](https://www.unm.edu/~lkravitz/Article%20folder/ACSMGuidelinesUNM.pdf) - 30 min x 5 days moderate or 20 min x 3 days vigorous; vigorous = RPE 14-17
- [Seiler 2010, What is best practice for training intensity and duration distribution in endurance athletes?, IJSPP](https://pubmed.ncbi.nlm.nih.gov/20861519/) - about 80/20 easy/hard session split in well-trained athletes; easy volume as the backbone
- [Stöggl & Sperlich 2015, The training intensity distribution among well-trained and elite endurance athletes, Front Physiol](https://www.frontiersin.org/journals/physiology/articles/10.3389/fphys.2015.00295/pdf) - 3-zone definitions (below VT1 / VT1 to RCP / above RCP)
- [Sylta, Tønnessen & Seiler 2014, From heart-rate data to training quantification: a comparison of 3 methods of training-intensity analysis, IJSPP](https://www.iat.uni-leipzig.de/datenbanken/iks/dsv-xc/Record/4030842) - time-in-zone undercounts hard work about 3x vs session goal; basis for counting interval blocks and not showing a minutes-based 80/20
- [Oliveira, Boppre & Fonseca 2024, Comparison of polarized versus other types of endurance training intensity distribution, Sports Med](https://pmc.ncbi.nlm.nih.gov/articles/PMC11329428) - polarised advantage small and limited to highly trained / under 12 weeks; reason to hide 80/20 from casual users
- [Vieira et al. 2022, Application and Measurement Properties of the Talk Test in Cardiopulmonary Patients: A Systematic Review, Rev Cardiovasc Med](https://pmc.ncbi.nlm.nih.gov/articles/PMC11266803/) - talk test validity; comfortable speech matches VT1
- [Relationship between the talk test and ventilatory thresholds in well-trained cyclists, J Strength Cond Res 2013](https://pubmed.ncbi.nlm.nih.gov/23007491/) - inability to talk lines up with the second threshold
- [Foster et al. 2001, A new approach to monitoring exercise training, J Strength Cond Res](https://sponet.de/sponet/Record/4006210) - session RPE tracks heart-rate-based load across steady and stop-start exercise
- [Haddad et al. 2017, Session-RPE Method for Training Load Monitoring: Validity, Ecological Usefulness, and Influencing Factors, Front Neurosci](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5673663/) - session RPE valid and practical across sports
- [Dantas et al. 2015, Determination of blood lactate training zone boundaries with rating of perceived exertion in runners, J Strength Cond Res](https://lida.sport-iat.de/ta/Record/4034541?lng=en) - CR-10 about 4.3 at 2 mmol and 6.5 at 4 mmol; 0-10 range per effort
- [Tanaka, Monahan & Seals 2001, Age-predicted maximal heart rate revisited, J Am Coll Cardiol](https://pubmed.ncbi.nlm.nih.gov/11153730/) - HRmax = 208 - 0.7 x age is a group average; HR zones only as an optional hint
- [Seiler-Viken et al. 2025, Contextualizing the Norwegian standardized intensity zone framework in an international sample of endurance practitioners, Sci Rep](https://pmc.ncbi.nlm.nih.gov/articles/PMC12491423/) - 5-zone to 3-zone mapping; %HRmax splits vary, so 80/88 % bands are approximate
- [Gastin 2001, Energy system interaction and relative contribution during maximal exercise, Sports Med](https://pubmed.ncbi.nlm.nih.gov/11547894/) - aerobic and anaerobic shares are about equal at about 75 s all-out; naming the red light by effort, not energy system
- [Milanović, Sporiš & Weston 2015, Effectiveness of HIT and continuous endurance training for VO2max improvements, Sports Med](https://research.tees.ac.uk/en/publications/effectiveness-of-high-intensity-interval-training-hit-and-continu-3/) - intervals improve VO2max somewhat more than continuous work; why the default target has hard minutes
- [Gist et al. 2014, Sprint interval training effects on aerobic capacity: a systematic review and meta-analysis, Sports Med](https://link.springer.com/doi/10.1007/s40279-014-0180-z) - sprint intervals raise VO2max about as much as endurance training
- [Herrmann et al. 2024, 2024 Adult Compendium of Physical Activities, J Sport Health Sci (values read at https://pacompendium.com/conditioning-exercise)](https://pubmed.ncbi.nlm.nih.gov/38242596/) - MET levels behind the default efforts
- [Muñoz-Martínez et al. 2017, Effectiveness of resistance circuit-based training for maximum oxygen uptake and upper-body 1RM improvements, Sports Med](https://repositorio.ucam.edu/handle/10952/3070) - short-rest weights circuits raise VO2max; basis for logging circuits as a cardio entry
- [Stølen et al. 2005, Physiology of soccer: an update, Sports Med](https://pubmed.ncbi.nlm.nih.gov/15974635/) - match play averages near threshold heart rate; team games default to Hard
- [Olstad et al. 2019, Maximal Heart Rate for Swimmers, Sports](https://pmc.ncbi.nlm.nih.gov/articles/PMC6915385) - lower heart rate in swimming; rate swim effort by feel
- [Elucidating the contribution of Rayleigh scattering to the bluish appearance of veins, J Biomed Opt 2018](https://www.spiedigitallibrary.org/journals/Journal-of-Biomedical-Optics/volume-23/issue-2/025001/Elucidating-the-contribution-of-Rayleigh-scattering-to-the-bluish-appearance/10.1117/1.JBO.23.2.025001.full) - venous blood is dark red and only looks blue through skin; red/blue is a drawing convention
