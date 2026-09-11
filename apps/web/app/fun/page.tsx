import type { Metadata } from "next";
import SiteHeader from "../SiteHeader";
import KeyboardPlayground from "./KeyboardPlayground";

export const metadata: Metadata = {
  title: "Fun mode — Try the keyboard sounds",
  description: "Find your favorite typing sound. Try 14 sound packs and seven keyboard designs before getting Assist for Mac.",
  alternates: { canonical: "/fun" }
};

export default function FunModePage() {
  return (
    <main>
      <SiteHeader funMode />
      <KeyboardPlayground />
    </main>
  );
}
