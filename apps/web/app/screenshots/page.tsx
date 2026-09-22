import ProductFeaturePage from "../ProductFeaturePage";
import { getProductFeature } from "../productContent";
import { createPageMetadata } from "../siteMetadata";

const feature = getProductFeature("/screenshots");

export const metadata = createPageMetadata({
  title: feature.metadataTitle,
  description: feature.metadataDescription,
  path: feature.path
});

export default function ScreenshotsPage() {
  return <ProductFeaturePage feature={feature} />;
}
