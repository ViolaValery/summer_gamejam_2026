# Krita-Figur -> Godot (Einzelteile)

Exportiert die Körperteil-Layer aus der Krita-Figur als einzelne PNGs,
zerlegt sie in saubere Ragdoll-Teile und erzeugt die Skelett-Daten.

## Ablauf (wenn du die Zeichnung in Krita änderst)
1. In Krita speichern (.kra), Pfad merken.
2. Teile zerlegen + farbig freistellen:
       python3 kra_parts.py /pfad/zur/figur.kra ../../assets/figur
3. Vorschaubild + Skelett-Daten neu erzeugen:
       python3 gen_skeleton.py
   -> gibt den `const PARTS`/`const BONES`-Block aus; in
      `scripts/figur.gd` ersetzen, falls sich Teile/Positionen geändert haben.

Layer-Namen in Krita müssen den Körperteilen entsprechen
(kopf, body, oberarm-links, ... siehe WANTED in kra_extract.py).
