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

export default function LoginOtpEmail() {
  return (
    <Html lang="en">
      <Tailwind>
        <Head />
        <Body className="bg-zinc-100 font-sans">
          <Preview>Your Rocketbox login code</Preview>
          <Container className="mx-auto max-w-[600px] px-4 py-8 pb-12">
            <Section className="overflow-hidden rounded-2xl bg-white shadow-sm">
              <Section className="px-7 py-8 pb-10 text-left">
                <Heading
                  as="h1"
                  className="m-0 mb-6 text-xl font-semibold leading-7 text-zinc-900"
                >
                  Your login code
                </Heading>

                <Text className="m-0 mb-4 text-base leading-6 text-zinc-800">
                  Hey there,
                </Text>

                <Text className="m-0 mb-4 text-base leading-6 text-zinc-800">
                  Use this code to sign in to Rocketbox as{' '}
                  <strong>{pm('user_email')}</strong>:
                </Text>

                <Text className="m-0 mb-6 text-center text-3xl font-semibold tracking-[0.35em] text-zinc-900">
                  {pm('otp_code')}
                </Text>

                <Text className="m-0 mb-4 text-base leading-6 text-zinc-800">
                  Or skip the code and sign in with this link:
                </Text>

                <Section className="mb-6 text-center">
                  <Button
                    href={pm('magic_login_url')}
                    className="inline-block rounded-lg bg-zinc-900 px-8 py-3 text-center text-sm font-semibold text-white no-underline"
                  >
                    Sign in to Rocketbox
                  </Button>
                </Section>

                <Text className="m-0 mb-2 text-base leading-6 text-zinc-800">
                  Or copy and paste this link into your browser:
                </Text>
                <Text className="m-0 mb-6 break-all text-sm leading-6 text-zinc-600">
                  {pm('magic_login_url')}
                </Text>

                <Text className="m-0 mb-6 text-base leading-6 text-zinc-800">
                  If you did not request this, you can safely ignore this email; it expires in 15
                  minutes.
                </Text>

                <Section className="my-6 border-t border-zinc-200" />

                <Text className="m-0 text-base leading-6 text-zinc-800">
                  Have questions or need help? Just reply to this email and our support team will
                  help you sort it out.
                </Text>
              </Section>
            </Section>
          </Container>
        </Body>
      </Tailwind>
    </Html>
  );
}
