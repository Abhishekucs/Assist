import { cancelRender, continueRender, delayRender, staticFile } from "remotion";

// Inter is the website's typeface and the one the macOS app bundles.
const handle = delayRender("Loading InterVariable.ttf");
const inter = new FontFace("Inter Assist", `url(${staticFile("fonts/InterVariable.ttf")}) format("truetype")`, {
  weight: "100 900"
});

inter
  .load()
  .then((face) => {
    document.fonts.add(face);
    continueRender(handle);
  })
  .catch((error: unknown) => cancelRender(error));
