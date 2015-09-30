# This file is part of KalibroClient
# Copyright (C) 2013  it's respectives authors (please see the AUTHORS file)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'spec_helper'

# Create a class that has the attribute assignment methods, since some methods expect they exist
# (and usually the subclasses do that).

class BaseTest < KalibroClient::Entities::Base
  attr_accessor :id, :created_at, :updated_at
end

describe KalibroClient::Entities::Base do
  subject { BaseTest.new }

  describe 'new' do
    subject { described_class.new({}) }

    it 'is expected to create a model from an empty hash' do
      expect(subject.kalibro_errors).to eq([])
    end
  end

  describe 'entity_name' do
    it 'is expected to be a String' do
      expect(subject.class.entity_name).to be_a(String)
    end

    it 'is expected to return Base' do
      expect(subject.class.entity_name).to eq('base')
    end
  end

  describe 'endpoint' do
    it 'is expected to return the entity_name' do
      endpoint = 'tests'
      described_class.expects(:entity_name).returns(endpoint)
      expect(described_class.endpoint).to eq(endpoint)
    end
  end

  describe 'client' do
    it 'returns a Faraday::Connection' do
      expect { described_class.client }.to raise_error(NotImplementedError)
    end
  end

  describe 'request' do
    context 'with successful responses' do
      let(:exists_response) { { 'exists' => false } }
      let(:bases_response) { { 'bases' => { 'id' => 1 } } }
      let(:prefix_bases_response) { { 'bases' => { 'id' => 2 } } }

      let(:connection) do
        Faraday.new do |builder|
          builder.adapter :test do |stubs|
            stubs.get('/bases/1/exists') { [200, {}, exists_response] }
            stubs.get('/bases/') { [200, {}, bases_response] }
            stubs.get('/prefix/bases/') { [200, {}, prefix_bases_response] }
          end
        end
      end

      before :each do
        subject.class.stubs(:client).returns(connection)
        subject.class.stubs(:endpoint).returns('bases')
      end

      context 'without an id parameter' do
        context 'without a prefix' do
          it 'is expected to make the request without the prefix' do
            response = subject.class.request('', {}, :get)
            expect(response).to eq(bases_response)
          end
        end

        context 'with a prefix' do
          it 'is expected to make the request with the prefix' do
            response = subject.class.request('', {}, :get, 'prefix')
            expect(response).to eq(prefix_bases_response)
          end
        end
      end

      context 'with an id parameter' do
        it 'is expected to make the request with the id included' do
          response = subject.class.request(':id/exists', { id: 1 }, :get)
          expect(response).to eq(exists_response)
        end
      end
    end

    context 'when the record was not found' do
      context 'and or the status is 404' do
        let!(:faraday_stubs) do
          Faraday::Adapter::Test::Stubs.new do |stub|
            # stub.get receives arguments: path, headers, block
            # The block should be a Array [status, headers, body]
            stub.get('/bases/1') { [404, {}, {}] }
          end
        end
        let!(:connection) { Faraday.new { |builder| builder.adapter :test, faraday_stubs } }

        before :each do
          described_class.stubs(:client).returns(connection)
        end

        it 'is expected to raise a RecordNotFound error' do
          expect { described_class.request(':id', { id: 1 }, :get) }.to raise_error(KalibroClient::Errors::RecordNotFound)
        end
      end

      context 'and or the response has a NotFound error message' do
        let!(:faraday_stubs) do
          Faraday::Adapter::Test::Stubs.new do |stub|
            # stub.get receives arguments: path, headers, block
            # The block should be a Array [status, headers, body]
            stub.get('/bases/1') { [422, {}, { 'errors' => 'RecordNotFound' }] }
          end
        end
        let!(:connection) { Faraday.new { |builder| builder.adapter :test, faraday_stubs } }

        before :each do
          described_class.stubs(:client).returns(connection)
        end

        it 'is expected to raise a RecordNotFound error' do
          expect { described_class.request(':id', { id: 1 }, :get) }.to raise_error(KalibroClient::Errors::RecordNotFound)
        end
      end
    end

    # This uses a different method to stub faraday calls, that doesn't rely on stubbing particular methods of the requests.
    # We should consider using it whenever possible instead of expectations.
    context 'with an unsuccessful request' do
      let!(:stubs) { Faraday::Adapter::Test::Stubs.new { |stub| stub.get('/bases/1/exists') { [500, {}, {}] } } }
      let(:connection) { Faraday.new { |builder| builder.adapter :test, stubs } }

      before :each do
        subject.class.stubs(:client).returns(connection)
      end

      it 'is expected to raise a RequestError with the response' do
        expect { subject.class.request(':id/exists', { id: 1 }, :get) }.to raise_error do |error|
          expect(error).to be_a(KalibroClient::Errors::RequestError)
          expect(error.response.status).to eq(500)
          expect(error.response.body).to eq({})
        end
      end
    end
  end

  describe 'to_hash' do
    it 'is expected to return an empty hash' do
      expect(subject.to_hash).to be_empty
    end
  end

  describe 'to_object' do
    it 'is expected to return an Object with an empty hash' do
      expect(described_class.to_object({})).to eq(FactoryGirl.build(:model))
    end

    it "is expected to remain an object if it isn't a Hash" do
      expect(described_class.to_object(Object.new)).to be_an(Object)
    end
  end

  describe 'to_objects_array' do
    it 'is expected to convert [{}] to [Model]' do
      expect(described_class.to_objects_array({})).to eq([FactoryGirl.build(:model)])
    end

    it 'is expected to remain an array if it already is one' do
      object = Object.new
      expect(described_class.to_objects_array([object])).to eq([object])
    end
  end

  shared_examples 'persistence method' do |method_name, http_method, has_id = true|
    before :each do
      subject.id = 42 if has_id
    end

    let(:url) { has_id ? ':id' : '' }
    let(:params) { has_id ? has_entry(id: 42) : anything }

    context 'when a record does not exist with given id' do
      before :each do
        subject.class.expects(:request).with(url, params, http_method, '').
          raises(KalibroClient::Errors::RecordNotFound)
      end

      it 'is expected to raise a RecordNotFound error' do
        expect { subject.send(method_name) }.to raise_error(KalibroClient::Errors::RecordNotFound)
      end
    end

    context 'when a server error is returned' do
      before :each do
        error = KalibroClient::Errors::RequestError.new(response: mock(status: 500))

        subject.class.expects(:request).with(url, params, http_method, '').raises(error)
      end

      it 'is expected to raise a RequestError error' do
        expect { subject.send(method_name) }.to raise_error(KalibroClient::Errors::RequestError)
      end
    end

    context 'when a regular kind of error is returned' do
      before :each do
        error = KalibroClient::Errors::RequestError.new(response: mock(status: 422, body: { 'errors' => errors }))

        subject.class.expects(:request).with(url, params, http_method, '').raises(error)
      end

      context 'with a single error' do
        let(:errors) { "error" }

        it 'is expected to set the kalibro_errors field' do
          expect(subject.send(method_name)).to eq(false)
          expect(subject.kalibro_errors).to eq([errors])
        end
      end

      context 'with an array of errors' do
        let(:errors) { ["error_1", "error_2"] }

        it 'is expected to set the kalibro_errors field' do
          expect(subject.send(method_name)).to eq(false)
          expect(subject.kalibro_errors).to eq(errors)
        end
      end

      context 'with no error message at all' do
        let(:errors) { nil }

        it 'is expected to set the kalibro_errors field' do
          expect(subject.send(method_name)).to eq(false)
          expect(subject.kalibro_errors.first).to be_a(KalibroClient::Errors::RequestError)
        end
      end
    end
  end

  describe 'save' do
    it_behaves_like 'persistence method', :save, :post, false # false means Don't use ids in URLs

    context 'with a successful response' do
      before :each do
        subject.class.stubs(:request).with('', anything, :post, '').
          returns({ "base" => { 'id' => 42, 'errors' => [] } })
      end

      context 'when it is not persisted' do
        it 'is expected to make a request to save model with id and return true without errors' do
          expect(subject.save).to be(true)
          expect(subject.id).to eq(42)
          expect(subject.kalibro_errors).to be_empty
        end
      end

      context 'when it is persisted' do
        before :each do
          subject.stubs(:persisted?).returns(true)
        end

        it 'is expected to call the update method' do
          subject.expects(:update).returns(true)
          expect(subject.save).to eq(true)
        end
      end
    end
  end

  describe 'update' do
    it_behaves_like 'persistence method', :update, :put

    context 'with valid parameters' do
      before :each do
        id = 42

        subject.stubs(:id).returns(id)
        described_class.expects(:request).with(':id', has_entry(id: id), :put, '').
          returns({ "base" => { 'id' => id, 'errors' => [] }})
      end

      it 'is expected to return true' do
        expect(subject.update).to eq(true)
      end
    end
  end

  describe 'create' do
    before :each do
      subject.expects(:save)
      described_class.
        expects(:new).
        with({}).
        returns(subject)
    end

    it 'is expected to instantiate and save the model' do
      expect(described_class.create {}).to eq(subject)
    end
  end

  describe 'find' do
    context 'with an inexistent id' do
      before :each do
        # We should remove this call in the future: there's no need to call exists before a find.
        subject.class.stubs(:exists?).with(0).returns(false)

        subject.class.stubs(:request).with(':id', has_entry(id: 0), :get).
          raises(KalibroClient::Errors::RecordNotFound)
      end

      it 'is expected to raise a RecordNotFound error' do
        expect { subject.class.find(0) }.to raise_error(KalibroClient::Errors::RecordNotFound)
      end
    end

    context 'with an existent id' do
      before :each do
        subject.class.stubs(:exists?).with(42).returns(true)
        subject.class.expects(:request).with(':id', has_entry(id: 42), :get).
          returns("base" => { 'id' => 42 })
      end

      it 'is expected to return an empty model' do
        expect(subject.class.find(42).id).to eq(42)
      end
    end
  end

  describe 'destroy' do
    it_behaves_like 'persistence method', :destroy, :delete

    context 'when it gets successfully destroyed' do
      before :each do
        subject.stubs(:id).returns(42)
        described_class.expects(:request).with(':id', { id: subject.id }, :delete, '').returns({})
      end

      it 'is expected to remain with the errors array empty and not persisted' do
        subject.destroy
        expect(subject.kalibro_errors).to be_empty
        expect(subject.persisted?).to eq(false)
      end
    end
  end

  describe 'save!' do
    it 'is expected to call save and not raise when saving works' do
      subject.expects(:save).returns(true)
      expect { subject.save! }.not_to raise_error
    end

    it 'is expected to call save and raise RecordInvalid when saving fails' do
      subject.expects(:kalibro_errors).returns(['test1', 'test2'])
      subject.expects(:save).returns(false)

      expect { subject.save! }.to raise_error { |error|
        expect(error).to be_a(KalibroClient::Errors::RecordInvalid)
        expect(error.record).to be(subject)
        expect(error.message).to eq('Record invalid: test1, test2')
      }
    end
  end

  describe '==' do
    subject { FactoryGirl.build(:model) }

    context 'comparing objects from different classes' do
      it 'is expected to return false' do
        expect(subject).not_to eq(Object.new)
      end
    end

    context 'with two models with different attribute values' do
      let(:another_model) { FactoryGirl.build(:model) }

      before :each do
        subject.expects(:variable_names).returns(["answer"])
        subject.expects(:send).with("answer").returns(42)
        another_model.expects(:send).with("answer").returns(41)
      end

      it 'is expected to return false' do
        expect(subject).not_to eq(another_model)
      end
    end

    context 'with two empty models' do
      it 'is expected to return true' do
        expect(subject).to eq(FactoryGirl.build(:model))
      end
    end
  end

  describe 'exists?' do
    context 'with an inexistent id' do
      before :each do
        described_class.
          expects(:request).
          with(':id/exists', { id: 0 }, :get).
          returns({ 'exists' => false })
      end

      it 'is expected to return false' do
        expect(described_class.exists?(0)).to eq(false)
      end
    end

    context 'with an existent id' do
      before :each do
        described_class.
          expects(:request).
          with(':id/exists', { id: 42 }, :get).
          returns({ 'exists' => true })
      end

      it 'is expected to return false' do
        expect(described_class.exists?(42)).to eq(true)
      end
    end
  end

  describe 'create_objects_array_from_hash' do
    subject { FactoryGirl.build(:model) }

    context 'with nil' do
      it 'is expected to return an empty array' do
        expect(described_class.create_objects_array_from_hash("bases" => [])).to eq([])
      end
    end

    context 'with a Hash' do
      it 'is expected to return the correspondent object to the given hash inside of an Array' do
        expect(described_class.create_objects_array_from_hash("bases" => {})).to eq([subject])
      end
    end
  end

  describe 'is_valid?' do
    context 'with a global var' do
      it 'is expected to return false' do
        expect(described_class.is_valid?('@test')).to be_falsey
      end
    end

    context 'with the attributes var' do
      it 'is expected to return false' do
        expect(described_class.is_valid?(:attributes!)).to be_falsey
      end
    end

    context 'with a xsi var' do
      it 'is expected to return false' do
        expect(described_class.is_valid?('test_xsi')).to be_falsey
      end
    end

    context 'with a valid var' do
      it 'is expected to return true' do
        expect(described_class.is_valid?('test')).to be_truthy
      end
    end
  end
end
