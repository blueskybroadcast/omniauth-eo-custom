require 'multi_json'

RSpec.describe OmniAuth::Strategies::EOCustom do
  let(:log) { double }
  let(:authenticate_body) { response_fixture('v3/authenticate') }
  let(:events_attended_body) { response_fixture('v3/events_attended') }
  let(:members_body) { response_fixture('v3/members') }
  let(:member_info) do
    {
      region: 'US East',
      country: 'United States of America',
      gender: 'Male',
      birthday: '2996'
    }
  end

  subject { described_class.new('app_id', 'secret') }

  before do
    allow(@app_event).to receive(:logs).and_return(log)
    allow(log).to receive(:create).and_return(true)
  end

  describe '#options' do
    describe '#name' do
      it { expect(subject.options.name).to eq('eo_custom') }
    end

    describe '#client_options' do
      describe '#authentication_url' do
        it { expect(subject.options.client_options.authentication_url).to eq('MUST_BE_PROVIDED') }
      end

      describe '#site' do
        it { expect(subject.options.client_options.site).to eq('https://api.eonetwork.org') }
      end

      describe '#client_id' do
        it { expect(subject.options.client_options.client_id).to eq('MUST_BE_PROVIDED') }
      end

      describe '#secret_key' do
        it { expect(subject.options.client_options.secret_key).to eq('MUST_BE_PROVIDED') }
      end

      describe '#username' do
        it { expect(subject.options.client_options.username).to eq('MUST_BE_PROVIDED') }
      end

      describe '#password' do
        it { expect(subject.options.client_options.password).to eq('MUST_BE_PROVIDED') }
      end
    end
  end

  describe '#info' do
    before do
      allow(subject).to receive(:fetch_member_details).and_return(response_fixture('v2/member'))
      stub_request(:get, 'https://api.eonetwork.org/v3/eo-members?ClientId=MUST_BE_PROVIDED&user_id=')
        .to_return(status: 200, body: MultiJson.dump(members_body))
      stub_request(:post, 'https://api.eonetwork.org/v3/Authenticate')
        .with(body: 'grant_type=password&client_id=MUST_BE_PROVIDED&username=MUST_BE_PROVIDED&password=MUST_BE_PROVIDED')
        .to_return(status: 200, body: MultiJson.dump(authenticate_body))
      stub_request(:get, 'https://api.eonetwork.org/v3/eo-members/events-attended?ClientId=MUST_BE_PROVIDED&user_id=')
        .to_return(status: 200, body: MultiJson.dump(events_attended_body))
    end

    context 'first_name' do
      it 'returns first_name' do
        expect(subject.info[:first_name]).to eq 'Bender'
      end
    end

    context 'last_name' do
      it 'returns last_name' do
        expect(subject.info[:last_name]).to eq 'Rodriguez'
      end
    end

    context 'email' do
      it 'returns email' do
        expect(subject.info[:email]).to eq 'bender@planet.express'
      end
    end

    context 'username' do
      it 'returns username' do
        expect(subject.info[:username]).to eq 'bendergetsbetter'
      end
    end

    context 'member_id' do
      it 'returns member_id' do
        expect(subject.info[:member_id]).to eq '1627aea5-8e0a-4371-9022-9b504344e724'
      end
    end

    context 'member_status' do
      it 'returns member_status' do
        expect(subject.info[:member_status]).to eq 'Member'
      end
    end

    context 'custom_fields_data' do
      context 'when response is success' do
        it 'returns additional data' do
          expect(subject.info[:custom_fields_data]).to eq member_info
        end
      end

      context 'when response is failed' do
        before do
          stub_request(:get, 'https://api.eonetwork.org/v3/eo-members?ClientId=MUST_BE_PROVIDED&user_id=')
            .to_return(status: 500, body: 'MemberEndpoint - No Members Found !!')
        end

        it 'returns blank data' do
          expect(subject.info[:custom_fields_data]).to eq({ region: '', country: '', gender: '', birthday: '' })
        end
      end
    end

    context 'access_codes' do
      context 'when response is success' do
        it 'returns access_codes' do
          expect(subject.info[:access_codes]).to eq ['ee853d29-39f5-e611-9423-00155df03a08', 'cb52fc27-b205-e711-9423-00155df03a08']
        end
      end

      context 'when response is failed' do
        before do
          stub_request(:get, 'https://api.eonetwork.org/v3/eo-members/events-attended?ClientId=MUST_BE_PROVIDED&user_id=')
            .to_return(status: 500, body: 'MemberEndpoint - No Members Found !!')
        end

        it 'returns blank data' do
          expect(subject.info[:access_codes]).to eq([])
        end
      end
    end
  end

  def response_fixture(filename)
    to_json(IO.read("spec/fixtures/#{filename}.json"))
  end

  def to_json(raw)
    MultiJson.load(raw, symbolize_keys: true)
  end
end
