"""Sample Peak JSON for App Store screenshots: a Mon/Wed/Fri routine of three workouts and 12 weeks of sessions
that follow double progression, ending the day before 2026-10-02 (a Friday, so Home shows a planned workout).

    python3 docs/app-store/make-sample-data.py en data-en.json   # or tr, for Turkish workout names

Import on the simulator with `-PeakTab settings -PeakImportFile <path> -PeakImportConfirm YES` (docs/DEVELOPMENT.md).
"""
import json, random, datetime as dt, sys
lang = sys.argv[1]; random.seed(7)
T = {
 'en': dict(push='Chest & Triceps', pull='Back & Biceps', legs='Legs & Shoulders', routine='Main Routine'),
 'tr': dict(push='Göğüs & Arka Kol', pull='Sırt & Ön Kol', legs='Bacak & Omuz', routine='Ana Rutin'),
}[lang]
N = {  # id: (en, tr, muscle, equipment, increment, start weight, sets)
 'bench': ('Bench Press','Bench Press','chest','barbell',2.5,60,3),
 'incline': ('Incline Dumbbell Press','Incline Dumbbell Press','chest','dumbbell',2.5,20,3),
 'pushdown': ('Triceps Pushdown','Triceps Pushdown','triceps','cable',2.5,25,3),
 'lat': ('Lat Pulldown','Lat Pulldown','back','machine',5,55,3),
 'row': ('Seated Cable Row','Seated Cable Row','back','cable',5,50,3),
 'curl': ('Incline Dumbbell Curl','Incline Dumbbell Curl','biceps','dumbbell',2.5,10,3),
 'squat': ('Squat','Squat','legs','barbell',5,70,3),
 'rdl': ('Romanian Deadlift','Romanian Deadlift','legs','barbell',5,60,3),
 'ohp': ('Shoulder Press','Shoulder Press','shoulders','dumbbell',2.5,15,3),
 'lateral': ('Lateral Raise','Lateral Raise','shoulders','dumbbell',1,8,3),
}
templates = {'push':['bench','incline','pushdown'],'pull':['lat','row','curl'],'legs':['squat','rdl','ohp','lateral']}
exercises=[dict(id=k,name=v[0 if lang=='en' else 1],muscleGroup=v[2],kind='strength',equipment=v[3],incrementKg=v[4]) for k,v in N.items()]
wt=[dict(id=t,name=T[t],kind='strength',items=[dict(exerciseId=e,targetSets=N[e][6]) for e in es]) for t,es in templates.items()]
routine=dict(id='main',name=T['routine'],active=True,schedule=dict(type='weekdays',days=['mon','wed','fri']),templateIds=['push','pull','legs'],createdAt='2026-07-06T08:00:00Z')
state={k:[v[5],9] for k,v in N.items()}  # weight, reps of first set
today=dt.date(2026,10,2); d=dt.date(2026,7,6); order=['push','pull','legs']; i=0; sessions=[]
while d<today:
  if d.weekday() in (0,2,4):
    t=order[i%3]; i+=1
    if random.random()<0.08: d+=dt.timedelta(1); continue  # a missed day
    start=dt.datetime(d.year,d.month,d.day,18,random.choice([0,5,10,15,30]))
    exs=[]
    for e in templates[t]:
      w,r=state[e]; sets=[]
      for s in range(N[e][6]):
        reps=max(5, r - s + random.choice([0,1,0,1,0,-1]))
        sets.append(dict(weight=w,reps=reps,targetWeight=w,targetReps=max(5,r-s),completed=True))
      exs.append(dict(exerciseId=e,completed=True,sets=sets))
      # double progression: first set over 12 -> weight up, reps reset to 6; else +1 rep
      if sets[0]['reps']>=12: state[e]=[w+N[e][4],6]
      else: state[e]=[w,r+1 if random.random()<0.9 else r]
    mins=random.randint(48,68)
    sessions.append(dict(id=f'{d}-{t}',date=str(d),startedAt=start.isoformat()+'Z',endedAt=(start+dt.timedelta(minutes=mins)).isoformat()+'Z',
      pausedTotalSec=0,status='completed',title=T[t],templateId=t,routineId='main',source='app',exercises=exs))
  d+=dt.timedelta(1)
water=[dict(loggedAt=f'2026-10-02T{h}:00:00Z',amountMl=a,source='app') for h,a in [('06',500),('08',330),('10',500)]]
data=dict(schema='peak.workout-data',schemaVersion=1,exportedAt='2026-10-02T09:00:00.000Z',units=dict(weight='kg'),exercises=exercises,
  workoutTemplates=wt,routines=[routine],sessions=sessions,waterLogs=water,
  settings=dict(stepGoal=10000,waterGoalMl=3000,overload=dict(thresholdReps=12,resetReps=6,repStep=1),unitSystem='metric',quickWaterAmounts=[200,330,500,1000]))
json.dump(data,open(sys.argv[2],'w'),ensure_ascii=False,indent=1)
print(len(sessions),'sessions', {k:v for k,v in state.items()})
