"""Run actual Godot tests; fail on script/runtime errors even if exit status is 0."""
import argparse,json,pathlib,subprocess,sys
p=argparse.ArgumentParser();p.add_argument('--godot',default='godot');a=p.parse_args()
root=pathlib.Path(__file__).resolve().parents[1];out=root/'reports';out.mkdir(exist_ok=True)
tests=['v4_smoke','v4_integrity_smoke','gem_smoke','unified_inventory_smoke','equipment_interaction_smoke','mobile_landscape_smoke','v5_smoke','configurable_hotbar_smoke','skill_aim_smoke','expedition_smoke','gem_expansion_smoke']
results=[]
for test in tests:
 r=subprocess.run([a.godot,'--headless','--path',str(root),'--script','res://tests/'+test+'.gd'],text=True,capture_output=True,timeout=60)
 log=r.stdout+r.stderr;(out/(test+'.log')).write_text(log)
 ok=r.returncode==0 and 'ERROR:' not in log and '_OK' in log
 results.append({'test':test,'passed':ok,'exit_code':r.returncode});print(test,'PASS' if ok else 'FAIL',flush=True)
 if not ok:print(log[-3000:],flush=True)
(out/'results.json').write_text(json.dumps(results,indent=2));sys.exit(0 if all(x['passed'] for x in results) else 1)
