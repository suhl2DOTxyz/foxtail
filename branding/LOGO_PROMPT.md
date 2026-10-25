# Foxtail logo — image generation prompts

Paste these into ChatGPT one at a time, in the same chat, so the second image matches the first.
Save the results into this folder (`branding/`) as `foxtail-logo.png` and `foxtail-glyph.png`.

---

## Prompt 1: full-color logo (`foxtail-logo.png`)

> Design an app icon / OS logo for an operating system called "Foxtail".
>
> **Subject:** a red fox curled into a perfect circle, chasing its own tail. The head is at the top of the circle with the snout pointing clockwise, and the open mouth is just about to catch the tip of its own bushy tail, which arcs around to meet it. The body forms the ring, and the center of the ring is empty (negative space). There should be a playful sense of motion, like the fox is spinning.
>
> **Style:** a premium, modern logo in the tradition of the Mozilla Firefox and macOS Big Sur app icons. Smooth vector-like illustration with soft gradients and subtle dimensional shading, not flat clip art and not photorealistic. Clean silhouette and crisp edges. Fur detail suggested through a few elegant sweeping shapes rather than individual hairs.
>
> **Colors:** warm orange palette. Main fur goes from a bright tangerine (#FF7A1A) to deep red-orange (#E5400A) in the shadows, with golden highlights (#FFA640) on top. The tail tip, chest and cheeks are cream/off-white (#FFF4E2). Small dark brown accents for the nose, eye, and the backs of the ears.
>
> **Composition:** centered, perfectly circular overall silhouette, filling about 85% of a square canvas. **Transparent background**, with no backdrop, no rounded-square tile, no text, no drop shadow onto a surface. It must stay recognizable when scaled down to 32×32 pixels.
>
> Output: 1024×1024 PNG with a transparent background.

## Prompt 2: monochrome menu-bar glyph (`foxtail-glyph.png`)

> Now make a simplified single-color version of that exact same logo for use as a 16-pixel menu-bar icon (like the Apple logo in the macOS menu bar). Pure solid black silhouette on a transparent background: no gradients, no inner detail except one or two negative-space cuts to separate the head from the tail and show the ear. Keep the same circular fox-chasing-its-tail shape, with bold, simple, chunky forms that remain readable at 16×16 pixels. 1024×1024 PNG, transparent background.

---

### Tips
- If the background comes out as a checkerboard pattern baked into the pixels (it happens), say: *"the background must be actually transparent (alpha channel), not a checkerboard pattern."*
- If the ring isn't closed or the fox looks like it's sitting, say: *"the fox's body itself must form the full circle; it's curled up and spinning."*
- Generate 3–4 variants and pick the one whose silhouette reads best when you squint.
