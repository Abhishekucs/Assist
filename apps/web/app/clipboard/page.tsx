import ProductFeaturePage from "../ProductFeaturePage";
import { getProductFeature } from "../productContent";
import { createPageMetadata, MODULES_SOCIAL_IMAGE } from "../siteMetadata";

const feature = getProductFeature("/clipboard");

export const metadata = createPageMetadata({
  title: feature.metadataTitle,
  description: feature.metadataDescription,
  path: feature.path,
  image: MODULES_SOCIAL_IMAGE
});

export default function ClipboardPage() {
  return <ProductFeaturePage feature={feature} />;
}
