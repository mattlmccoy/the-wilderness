# Context research: Moretto da Brescia, *Christ in the Wilderness* (Met 11.53)

Compiled 2026-11-11. Each bullet: fact — source — short quote or paraphrase.
Labels: **[source]** = a source says this about this painting; **[general]** = sourced, but about the motif in general, not this painting; **[inference]** = my reasoning, not a source; **[visual]** = my own reading of crops of the Met's 4000 px image (`DP-19630-001.jpg`), not a source.

Pages read on 2026-11-11: Met collection page (Overview, Catalogue Entry by Andrea Bayer 2014, Provenance, Exhibition History, References), Met API JSON, two Met essays, Met Bulletin 2003 (PDF), Zeri/Gardner 1986 catalogue (PDF, OCR of pp. 43–44), National Gallery NG3096, Treccani DBI.

Key URLs:
- MET = https://www.metmuseum.org/art/collection/search/437157
- API = https://collectionapi.metmuseum.org/public/collection/v1/objects/437157
- ZERI = Zeri & Gardner, *Italian Paintings: North Italian School* (Met, 1986), pp. 43–44, PDF via https://www.metmuseum.org/met-publications/italian-paintings-a-catalogue-of-the-collection-of-the-metropolitan-museum-of-art-vol-4-north-ita
- BULL = Bayer, "North of the Apennines," *Met Museum Bulletin* 60, no. 4 (Spring 2003), pp. 26–27, PDF via https://www.metmuseum.org/met-publications/north-of-the-apennines-the-metropolitan-museum-of-art-bulletin-v-60-no-4-spring-2003
- DBI = https://www.treccani.it/enciclopedia/bonvicino-alessandro-detto-il-moretto-da-brescia_(Dizionario-Biografico)/ (Angela Ottino Della Chiesa, DBI vol. 12, 1971)

---

## 0. Corrections to what the app already claims (read this first)

- **Basilisk: the Met does name it.** `annotations.json` says the creature "is not named in the Met's record". That is wrong. The Met's overview and catalogue both name it, and the catalogue ties the snake and lion to Psalm 91:13. The evidence level can go from `plausible` to `documented`. — MET (Overview) — "a small dragon or basilisk creeps at his feet"; MET (Catalogue Entry) — the Psalm verse "would also account for the dragon or basilisk-type animal at the center"
- **Lion and snake: the Met cites Psalm 91:13 for them too.** — MET (Catalogue Entry) — "The appearance of a snake and a lion probably alludes to a verse from the Psalms (91:13)"
- **Bear and fox: the evidence is the Met's subject tags, not its catalogue text.** The app says "The Met's catalogue lists" a bear and foxes. The catalogue entry, Zeri 1986 and the 2003 Bulletin name no ordinary animals. The API `tags` field lists Bears, Birds, Deer, Foxes, Lions, Angels and Christ. Tags do not say which painted animal is which. — API — `tags: Bears, Birds, Deer, Foxes, Lions, Angels, Christ`
- **The tree is identified, as a beech.** The app calls the tree reading "an interpretation". Both a Met essay and the Met catalogue identify it as a beech and give its meaning. — https://www.metmuseum.org/essays/botanical-imagery-in-european-painting (Jennifer Meagher, 2007) — "a beech tree reminds the viewer of Christ's abstinence"; ZERI p. 43 — "The beech tree is an attribute of Christ, and a symbol of abstinence."
- **"Pelican" is not supported by any source, and the bird does not look like one.** [visual] At x ≈ 0.53–0.60, y ≈ 0.29–0.36, the white bird has a long thin S-curved neck, a straight dagger-shaped bill, and long reddish legs. That fits a heron, egret or crane, not a pelican (no pouch, no hooked bill). No Met, Zeri or Bulletin text names it. A popular article (lead only, not authoritative) lists both a "crane" and a "pelican" among the birds without saying which is which: https://www.indiancatholicmatters.org/animals-allegories-and-art-christ-in-the-wilderness/ (J. Fernandes, 2023).
- **The National Gallery dates the London companion piece differently.** — https://www.nationalgallery.org.uk/paintings/moretto-da-brescia-christ-blessing-saint-john-the-baptist — page title gives "about 1520-3"; the Met dates both pictures "ca. 1515–20".

---

## 1. The black bird, upper left (x 0.16–0.27, y 0.17–0.24)

**No source identifies this bird in this painting.**
- [source] The Met's only label for it is the generic subject tag "Birds". — API — `tags: … Birds …`
- [source] The 2003 Bulletin speaks of the animals generally. — BULL p. 27 — "Most of the animals gathering near the seated Christ are recognizable"
- [visual] Raven is the best guess. The bird is wholly black, large, and heavy-billed, with a shaggy, ragged throat and nape. It is bent over pecking at the rock top. A shaggy throat ("hackles") and a heavy bill are field marks of the common raven rather than the carrion crow. The brushwork is sketchy, though, so "raven or crow" is the honest label. A hooded crow is ruled out because it would show grey.
- [visual] There are at least five other birds:
  - a white bird with spread wings, just right of the black bird (x ≈ 0.28, y ≈ 0.16);
  - a small dark bird on a broken branch of the left tree (x ≈ 0.41, y ≈ 0.23);
  - a dark bird with a white belly, magpie-like, lower left (x ≈ 0.25, y ≈ 0.79);
  - a brown hawk- or falcon-like bird on a rock, bottom centre (x ≈ 0.41, y ≈ 0.83);
  - a pale bird with a curved neck lying at the bottom right (x ≈ 0.75, y ≈ 0.90).
  None of these is named by any source I found.

**General symbolism of the raven. None of these sources ties it to this painting.**
- [general] In Scripture, the raven could mean a preacher, a sinner or the Devil. — https://www.abdn.ac.uk/bestiary/ms24/f37r (Aberdeen Bestiary, University of Aberdeen translation) — "sometimes … a preacher, sometimes a sinner, sometimes the Devil" (close paraphrase of the folio's line)
- [general] Ravens fed the prophet Elijah in the wilderness by the brook Cherith (1 Kings 17:4–6). — https://www.nationalgallery.org.uk/paintings/guercino-elijah-fed-by-ravens — "ravens delivered bread and meat to him every morning and evening"
- [general] The same museum reads the ravens as nourishment of both body and soul. — same URL — the birds "represent both physical and spiritual nourishment"
- [general] In the desert-hermit tradition, a raven brought Saint Paul the Hermit his daily bread (from Jerome's *Life of Paul*). — https://blog.metmuseum.org/artofillumination/2010/05/26/saints-paul-and-anthony/ (Met, on the Belles Heures, Cloisters 54.1.1) — Paul "was fed by a daily delivery of bread by a raven"
- [source, about Moretto] Moretto later painted Elijah fed in the wilderness himself, in the angel version of the story (1 Kings 19:5–8). His canvases for the Sacrament chapel of San Giovanni Evangelista, Brescia (commissioned 1521), include an *Elia e l'angelo*, and an *Elia dormiente* followed in 1531–34. — DBI — "Elia e l'angelo"; "Elia dormiente"
- [inference] For a guest, a fair line would be: "Ravens were the wilderness's providers in Scripture and legend: they fed Elijah and the hermit Paul." Do not say Moretto meant this. No source says so, and the bird is pecking at the rock, not carrying food.
- [general, lead only] Augustine's reading of the raven's cry as "cras, cras" ("tomorrow, tomorrow", meaning procrastination) is cited only by the popular article above. I did not confirm it upstream.

## 2. The "unknown creature", centre (x 0.41–0.51, y 0.36–0.53)

- [source] No source names this animal. The Met catalogue, Zeri 1986 and the 2003 Bulletin name only the lion, the snake, the dragon or basilisk, the angels and the cherubim. The Met's tags list Bears, Deer, Foxes and Lions (plus Birds). — MET Catalogue Entry; ZERI p. 43; BULL p. 27; API tags
- [visual] It is a large four-legged animal in grey-brown fur, partly behind the tree trunk at left. Its hindquarters are high at the left and its back is rounded and arched. The forelegs run down the slope, and the head is lowered to the right, close to the rock and partly lost in shadow. It is about twice the bulk of the fox below it. No antlers, mane or spotted coat are visible, and the tail is not clearly visible.
- [visual, guess] **Most likely a second bear, coming down the rocks with its head lowered. A wolf is the alternative.** Reasons: the bulk, the rounded back and the thick legs suit a bear. Among the Met's tag species (bear, deer, fox, lion), it is not a deer (no antlers, body too heavy), not a fox (too large and grey), and not a lion (no mane, wrong colour beside the lion at lower right). Confidence is low. The brushwork here is thin and sketch-like, and Wehle (1940) called the whole picture as free as a sketch (MET References — "with the freedom of a sketch").
- [visual, related caution] The grey animal lying at the bottom centre (the app's "bear", x ≈ 0.55, y ≈ 0.74) has a bristly coat and a long, low snout. It could be read as a wild boar as well as a bear. The Met tag "Bears" does not say which animal it refers to.
- Suggested in-app wording: "An animal comes down the rocks with its head lowered, perhaps a second bear. No source names it." Evidence level: `plausible` at most.

## 3. The landscape and the Holy Land

- [source] The Met says the London and New York pictures have similar landscapes. It does not say the landscape shows any real region. — MET Catalogue Entry — "have similar landscapes and palette"
- [source] The Met's essay presents the landscape as an artistic opportunity, not a place. — https://www.metmuseum.org/essays/painting-the-life-of-christ-in-medieval-and-renaissance-italy — the theme gave Moretto "license to create a landscape animate with birds and animals"
- [source] The Bulletin links the way the animals are spread across the land to Pisanello's tradition, about 50 years earlier. — BULL p. 27 — the creatures are "suggestive of how Pisanello painted animals"
- [source] Treccani describes Moretto's art as Lombard at root (Foppa's "constructive light", a "Lombard perspective"). This is about his style, not about this landscape. — DBI — "è sempre la prospettiva lombarda, la luce costruttiva"
- **No source found** says these hills are Lombard or Brescian, or that they try to show Judea. [inference] The beech tree, a northern-European tree (see §0), suggests a familiar Alpine-foothill setting rather than a studied Judean one. That is a reading, not a sourced claim.
- **No source found** for any journey by Moretto to the Holy Land. The documented trips in Treccani are to Milan, to Bergamo (paid "per il viaggio da Brescia a Bergamo", 1529) and to Isabella d'Este at Solarolo (1535). Scholars have proposed a stay in Padua or Venice. — DBI — "si è fondatamente ipotizzata una residenza a Padova … o anche a Venezia"

## 4. The real place

All Bible references are given as references only.
- [Scripture] The order of events: Jesus is baptized in the Jordan, then the Spirit at once drives him into the wilderness for forty days, "with the wild beasts", and angels serve him. — Mark 1:9–13 (parallels Matthew 4:1–11; Luke 4:1–13)
- [source] The National Gallery reads Moretto's London companion as the moment between these two events. — https://www.nationalgallery.org.uk/paintings/moretto-da-brescia-christ-blessing-saint-john-the-baptist — Christ "may have just been baptised … and is now about to go into the wilderness"
- [source] The Mount of Temptation is about 5 km north-west of Jericho, in the West Bank. — https://www.seetheholyland.net/mount-of-temptation/ — "about 5km north-west of the West Bank city of Jericho"
- [source] Its names come from the forty days. — same — "also known as Mount Quarantania and Jebel Quarantul", from Latin for forty
- [source] Tradition places two temptations there: the stone-to-bread temptation in a grotto halfway up, and the kingdoms-of-the-world temptation on the summit. — same — "Tradition dating from the 12th century places two of the devil's temptings"
- [source] Monastic history: hermits lived in the caves from early Christian centuries. A 4th-century Byzantine monastery was abandoned after the Persian invasion of 614. — same — "monks abandoned the site after the Persian invasion of 614"
- [source] The present Greek Orthodox Monastery of the Temptation was rebuilt in the late 19th century and is partly cut into the cliff. — same — "reconstructed at the end of the 19th century"
- [source] Jericho is one of the oldest continuously settled towns in the world. — https://www.britannica.com/place/Jericho-West-Bank — "one of the earliest continuous settlements in the world"
- [source] The Dead Sea lies about 430 m below sea level, with the hills of Judaea on its west. — same Britannica page (Dead Sea panel) — "about 1,410 feet (430 metres) below sea level"; "between the hills of Judaea to the west"
- [source, read only through the search index; the page would not load] UNESCO's Tentative List entry "El-Bariyah: wilderness with monasteries" (submitted by Palestine, 2012) places the Judean wilderness between the hills of Jerusalem, Bethlehem and Hebron and the Dead Sea, in the rain shadow of the central highlands (rainfall about 400 mm in the west to 150 mm in the east). — https://whc.unesco.org/en/tentativelists/5708 — re-check before use

## 5. Brescia and Moretto, around 1515–20

- [source] The artist's name and dates. — API — "Moretto da Brescia (Alessandro Bonvicino)", "Italian, Brescia ca. 1498–1554 Brescia"
- [source] The birth year comes from his own tax return: in 1548 he declared he was "about fifty". — DBI — "dichiarò di avere 'anni circa cinquanta'"
- [source] The nickname came from his grandfather. His father Pietro was "son of Moretto", hence the surname-like name. Pietro was a modest painter and had died by 7 August 1515. — DBI — "Il padre Pietro, figlio di Moretto, donde il soprannome"
- [source] The earliest documented commission is a contract of 7 August 1515 for the organ shutters of Brescia's Old Cathedral, shared with Floriano Ferramola. Moretto was then about eighteen. — DBI — "il pittore diciottenne"
- [source] Brescia belonged to Venice from 1426. — https://www.britannica.com/place/Brescia-Italy — "passing to Venice in 1426"
- [source] The sack of 1512: Brescia was "one of the wealthiest cities in Lombardy" and "never recovered from its sack by the French under Gaston II, comte de Foix, in 1512". — same Britannica page
- [source] Treccani calls the sack the city's punishment for returning to Venetian allegiance. — https://www.treccani.it/enciclopedia/brescia_(Enciclopedia-Italiana)/ — "terribile saccheggio di Gian Gastone di Foix nel 1512"
- [source] Gaston de Foix retook Brescia, defeated the Venetians, and died at Ravenna on 11 April 1512. — https://www.treccani.it/enciclopedia/foix-gaston-de-duca-di-nemours/ — "riconquistando Brescia"; "l'11 apr. 1512 … a Ravenna"
- [source] Brescia's 2024 exhibition starts its story of the city's Renaissance with the sack. — https://www.bresciamusei.com/en/event/il-rinascimento-a-brescia-moretto-romanino-savoldo-1512-1552/ — "begins with the evocation of the Sack of 1512"
- [source] Moretto and Romanino led painting in Venetian Brescia. — MET Catalogue Entry — Brescia was "then in the westernmost area of Venice's mainland empire"
- [inference] Moretto was about 14 in 1512 and was painting this picture within roughly 3 to 8 years of the sack. No source links the painting's mood to the sack. Treat that only as a possibility.

## 6. How the painting reached the Met, and whether it is on view

- [source] Rogers Fund, 1911; accession 11.53. — API — `creditLine: Rogers Fund, 1911`; `accessionYear: 1911`
- [source] The Met curator Bryson Burroughs bought it in 1911, as part of a deliberate group of Brescian paintings. — MET Catalogue Entry — "purchased for The Metropolitan Museum by the curator Bryson Burroughs in 1911"
- [source] Provenance: possibly the Vantini collection in Brescia (1826); Bonomi-Cereda family, Milan (by 1860–96; withdrawn from their 1896 sale); Lotmar, Bern; a private collection in Milan; then Jean Paul Richter in Florence, who sold it to the Met in 1911. — MET Provenance — "[Jean Paul Richter, Florence, 1911; sold to The Met]"
- [source] An 1826 Brescia guide probably described this picture as a *Saint John in the Desert*. — MET References (Brognoli 1826) — "mentions a Saint John in the desert by Moretto, probably this picture"
- [source] It was on view on 2026-11-11. — MET — "On view at The Met Fifth Avenue in Gallery 611"; API `GalleryNumber: 611`
- [source] It travelled back to Brescia for the 2024–25 exhibition. — MET Exhibition History — "Il Rinascimento a Brescia … October 18, 2024–February 16, 2025, no. 20"

## 7. Other things that change how a guest looks

- [source] **The hidden angels and cherubs.** The picture had been cut down at the left and top, and the angels and cherubim were painted over to hide this. A 1988 restoration uncovered them; X-rays had already shown them. — MET Catalogue Entry — "uncovered two small angels in the upper right"; MET Overview — "the angels and cherubim were painted over"
- [source] **Who the cherubs surrounded.** The cherub heads probably formed a radiance around God the Father, who was shown ordering the angels to serve Christ. — MET Catalogue Entry — "a radiance surrounding a figure of God the Father"
- [source] **Two lost creatures.** Zeri noted two fantastic creatures in the upper-left corner, then almost invisible. — ZERI p. 43 — "two fantastic creatures in the upper left corner are now so faint as to be almost illegible"
- [source] **The beech tree**, with its etymology. The Met says the name derives from the Greek for "to eat", because hermits fed on its nuts. — https://www.metmuseum.org/essays/botanical-imagery-in-european-painting — "its nuts provided sustenance for ascetics"
- [source] **A rare subject.** Eisler (1935) noted how rare the subject is. — MET References — "notes the rarity of the subject"
- [source] **Painted for the home.** Guazzoni (1981) grouped it with three related works "meant for private, domestic devotions". — MET References
- [source] **Christ's stillness is the point.** — BULL p. 27 — "almost oblivious to the swirl of activity around him"
- [source] **Possibly a donor portrait.** The lost larger work might have included a donor portrait. — MET Catalogue Entry — "possible that the work … included the portrait of a donor"
- [general] Psalm 91:13, cited by the Met for the lion, snake and dragon or basilisk (Vulgate 90:13), is also the psalm the tempter quotes (verses 11–12) in Matthew 4:6. The Met does not mention the Matthew link; that is a Scripture cross-reference, not a Met claim.
- Stag (Psalm 42:1), pelican (self-wounding) and bear: I found no source that ties any of these readings to this painting. Keep them labelled as tradition or interpretation.

---

## Not found / uncertain

- No source identifies the upper-left black bird, the central quadruped, or any individual bird. Raven and bear are my visual guesses only.
- No source supports "pelican"; the bird looks like a heron, egret or crane (visual).
- The Met's "Bears" and "Foxes" are API subject tags. Which painted animals they refer to is not stated.
- No source says the landscape is Lombard, or that Moretto tried to depict Judea.
- No evidence that Moretto ever travelled to the Holy Land.
- Brescia's return to Venice in 1516 (after French, then Spanish and Imperial, control from 1512): widely stated, but I did not confirm it in a source I could read. Sources disagree (one Wikipedia page says 1520). Do not use without checking.
- How old the Mount of Temptation tradition is: See the Holy Land says the tradition placing temptations on the mountain dates from the 12th century, with monks there from the 4th century. Wikipedia (a lead only) says "at least the 4th century". Chariton's founding of the Douka laura, the 1133–34 crusader priory and the 1895 rebuilding date all come from Wikipedia and were not confirmed upstream.
- UNESCO El-Bariyah text: read only through the search index; the page returned nothing.
- Augustine's "cras, cras" reading of the raven: popular source only.
- Not read: Penny 2004 (National Gallery catalogue), Eisler 1935, Levi d'Ancona 1977, Turati 2024 (Brescia catalogue no. 20). These may name the animals. Turati 2024 dates the picture "about 1514–15" (MET References).
