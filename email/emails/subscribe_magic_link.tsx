import {
  Body,
  Button,
  Container,
  Head,
  Heading,
  Html,
  Preview,
  Section,
  Tailwind,
  Text,
} from 'react-email';
import { pm } from './utils/postmarkMerge';

export default function SubscribeMagicLinkEmail() {
  return (
    <Html lang="en">
      <Tailwind>
        <Head />
        <Body className="bg-zinc-100 font-sans">
          <Preview>Subscribe to Rocketbox</Preview>
          <Container className="mx-auto max-w-[600px] px-4 py-8 pb-12">
            <Section className="overflow-hidden rounded-2xl bg-white shadow-sm">
              <Section className="px-7 py-8 pb-10 text-left">
                <Heading
                  as="h1"
                  className="m-0 mb-6 text-xl font-semibold leading-7 text-zinc-900"
                >
                  Subscribe to Rocketbox
                </Heading>

                <Text className="m-0 mb-4 text-base leading-6 text-zinc-800">Hi,</Text>

                <Text className="m-0 mb-4 text-base leading-6 text-zinc-800">
                  Use the secure magic link below to continue with your Rocketbox subscription.
                </Text>

                <Section className="mb-6 text-center">
                  <Button
                    href={pm('subscribe_url')}
                    className="inline-block rounded-lg bg-zinc-900 px-8 py-3 text-center text-sm font-semibold text-white no-underline"
                  >
                    Continue subscribing
                  </Button>
                </Section>

                <Text className="m-0 mb-2 text-base leading-6 text-zinc-800">
                  Or copy and paste this URL:
                </Text>
                <Text className="m-0 mb-6 break-all text-sm leading-6 text-zinc-600">
                  {pm('subscribe_url')}
                </Text>

                <Text className="m-0 mb-4 text-base leading-6 text-zinc-800">
                  This link expires in {pm('expiration_phrase')} for your inbox&apos;s safety.
                </Text>

                <Text className="m-0 text-base leading-6 text-zinc-800">— The Rocketbox team</Text>
              </Section>
            </Section>
          </Container>
        </Body>
      </Tailwind>
    </Html>
  );
}
