import type { Metadata } from "next";
import { redirect } from "next/navigation";

export const metadata: Metadata = {
  robots: {
    index: false,
    follow: false
  }
};

type SuccessPageProps = {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

function appendParam(query: URLSearchParams, key: string, value: string | string[]) {
  if (Array.isArray(value)) {
    for (const item of value) {
      query.append(key, item);
    }

    return;
  }

  query.set(key, value);
}

export default async function PurchaseSuccess({ searchParams }: SuccessPageProps) {
  const params = await searchParams;
  const query = new URLSearchParams();

  for (const [key, value] of Object.entries(params)) {
    if (value) {
      appendParam(query, key, value);
    }
  }

  const target = query.toString()
    ? `/purchase/result?${query.toString()}`
    : "/purchase/result";

  redirect(target);
}
