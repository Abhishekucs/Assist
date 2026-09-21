import ProductFeaturePage from "../ProductFeaturePage";
import { getProductFeature } from "../productContent";
import { createPageMetadata } from "../siteMetadata";

const feature = getProductFeature("/clipboard");

export const metadata = createPageMetadata({
  title: feature.metadataTitle,
  description: feature.metadataDescription,
  path: feature.path
});

export default function ClipboardPage() {
  return <ProductFeaturePage feature={feature} />;
}
