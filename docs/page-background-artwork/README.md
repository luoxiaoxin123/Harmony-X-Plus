# Generated wallpaper motifs

88 transparent outline motifs generated with ImageGen. The prep script crops the source atlases and makes matching black and white ink variants.

- [Selection preview](selection-preview.png)
- [Plants vs. Zombies source atlas](pvz-atlas.png)
- [AI assistant atlas, prompt and preview](ai-generation.md)
- [Mobile brand/system atlas, prompt and preview](mobile-generation.md)
- [Popular app atlases, prompts and previews](apps-generation.md)
- [Crop manifest](motifs.json)
- Preparation: `tools/Prepare-PageSignatureMotifs.cjs` (Sharp; set HARMONYX_SHARP to its installed module path).
- Production files: `entry/src/main/resources/{base,dark}/media/page_motif_garden_defense_*.png`, 256 by 256, transparent PNG.

All five sets are available in Page background > Individual motifs. Each motif can be selected separately, mixed with any other set, and included in portable .hxb schemes. Full-pattern collections remain available separately.

## Plants vs. Zombies atlas prompt

Use case: stylized-concept. Create ONE production sprite atlas for Plants vs. Zombies themed app wallpaper motifs. Transparent background, clean elegant black monoline cartoon doodles, consistent rounded 7-9px outlines, mostly transparent interiors with tiny solid-black pupils only. Exactly 4 columns by 3 rows, 12 separate fully contained motifs, one in the center of each equal grid cell, all same apparent scale, very generous empty transparent gutters. No words, no letters, no logos, no numbers, no borders, no scene, no white fill, no color, no gradients, no texture, no background, no shadows. Landscape canvas roughly 1536x1152. Make the recognizable classic Plants vs. Zombies silhouettes cute and simplified enough to read as small 40vp wallpaper icons. Precise order left to right, top to bottom: 1 Peashooter with round trumpet snout, stalk and two leaves; 2 smiling Sunflower with round face and ring of petals; 3 startled Wall-nut with wavy shell and two oval eyes; 4 Cherry Bomb pair attached by short stem; 5 Snow Pea with trumpet snout and four icy head spikes; 6 Potato Mine with small red-light-shaped stalk on top but drawn monochrome; 7 Chomper open toothy mouth and leafy stalk; 8 Squash with grumpy brow and small stalk; 9 goofy classic zombie head, two large uneven eyes, missing tooth and sparse hair; 10 Conehead Zombie bust with tall traffic cone; 11 Buckethead Zombie bust with bucket and loose tie; 12 small lawn mower side view with handle and two wheels. Keep outlines readable and not overly detailed. All 12 isolated designs remain wholly inside their own cell without touching or crossing cell margins.
