require 'rspec/mocks'
require 'faraday'
require 'likeno'
require 'kalibro_client/kalibro_cucumber_helpers'

describe KalibroClient::KalibroCucumberHelpers::Cleaner do
  let(:address_key) { :test_address }
  let(:likeno_config) { {address_key => 'http://test'} }

  subject { described_class.new(address_key) }

  describe 'endpoint' do
    it 'is expected to return "tests"' do
      expect(subject.endpoint).to eq('tests')
    end
  end

  describe 'base_address' do
    it 'is expected to find the address in Likeno' do
      expect(subject.address).to eq(address_key)
    end
  end

  describe 'clean_database' do
    let(:client) { mock("client") }
    let(:request) { mock("request") }
    let(:response) { mock("response", success?: true, body: '') }
    let(:options) { stub_everything }

    it 'is expected to make a request to the correct address' do
      subject.expects(:request).with('clean_database',  {}, :post)

      subject.clean_database
    end
  end
end
