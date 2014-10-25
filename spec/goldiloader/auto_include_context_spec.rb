require 'spec_helper'
require 'ostruct'

describe Goldiloader::AutoIncludeContext do
  describe ".register_models" do
    context "when included_associations is an array of symbols" do
      let!(:roots) do
        [
          create_mock_model(cars: cars.take(2), fruit: fruits.first),
          create_mock_model(cars: cars.drop(2).take(2), fruit: fruits.last)
        ]
      end
      let!(:cars) { create_mock_models(4) }
      let!(:fruits) { create_mock_models(2) }

      before do
        Goldiloader::AutoIncludeContext.register_models(roots, [:cars, :fruit])
      end

      it "sets the AutoIncludeContext for roots" do
        expect(roots.map(&:auto_include_context).uniq.size).to eq 1
        expect(roots.first.auto_include_context.models).to match_array(roots)
      end

      it "sets the AutoIncludeContext for singluar nested associations" do
        expect(fruits.map(&:auto_include_context).uniq.size).to eq 1
        expect(fruits.first.auto_include_context.models).to match_array(fruits)
      end

      it "sets the AutoIncludeContext for collection nested associations" do
        expect(cars.map(&:auto_include_context).uniq.size).to eq 1
        expect(cars.first.auto_include_context.models).to match_array(cars)
      end
    end

    context "when included_associations is a hash" do
      let!(:roots) do
        [
          create_mock_model(car: cars.first),
          create_mock_model(car: cars.last)
        ]
      end

      let!(:cars) do
        [
          create_mock_model(wheels: wheels.take(4)),
          create_mock_model(wheels: wheels.drop(4).take(4))
        ]
      end

      let!(:wheels) { create_mock_models(8) }

      before do
        Goldiloader::AutoIncludeContext.register_models(roots, car: :wheels)
      end

      it "sets the AutoIncludeContext for roots" do
        expect(roots.map(&:auto_include_context).uniq.size).to eq 1
        expect(roots.first.auto_include_context.models).to match_array(roots)
      end

      it "sets the AutoIncludeContext for child nested associations" do
        expect(cars.map(&:auto_include_context).uniq.size).to eq 1
        expect(cars.first.auto_include_context.models).to match_array(cars)
      end

      it "sets the AutoIncludeContext for grandchild nested associations" do
        expect(wheels.map(&:auto_include_context).uniq.size).to eq 1
        expect(wheels.first.auto_include_context.models).to match_array(wheels)
      end
    end

    context "when included_associations is an array that mixes hashes and symbols" do
      let!(:roots) do
        [
          create_mock_model(car: cars.first, person: people.first),
          create_mock_model(car: cars.last, person: people.last)
        ]
      end

      let!(:people) { create_mock_models(2) }

      let!(:cars) do
        [
          create_mock_model(wheels: wheels.take(4)),
          create_mock_model(wheels: wheels.drop(4).take(4))
        ]
      end

      let!(:wheels) { create_mock_models(8) }

      before do
        Goldiloader::AutoIncludeContext.register_models(roots, [:person, car: :wheels])
      end

      it "sets the AutoIncludeContext for roots" do
        expect(roots.map(&:auto_include_context).uniq.size).to eq 1
        expect(roots.first.auto_include_context.models).to match_array(roots)
      end

      it "sets the AutoIncludeContext for child nested associations specified with a symbol" do
        expect(people.map(&:auto_include_context).uniq.size).to eq 1
        expect(people.first.auto_include_context.models).to match_array(people)
      end

      it "sets the AutoIncludeContext for child nested associations specified with a hash" do
        expect(cars.map(&:auto_include_context).uniq.size).to eq 1
        expect(cars.first.auto_include_context.models).to match_array(cars)
      end

      it "sets the AutoIncludeContext for grandchild nested associations" do
        expect(wheels.map(&:auto_include_context).uniq.size).to eq 1
        expect(wheels.first.auto_include_context.models).to match_array(wheels)
      end
    end

    context "when nested associations are nil" do
      let!(:roots) do
        [
            create_mock_model(car: cars.first),
            create_mock_model(car: nil),
            create_mock_model(car: cars.last)
        ]
      end

      let!(:cars) do
        [
            create_mock_model,
            create_mock_model
        ]
      end

      before do
        Goldiloader::AutoIncludeContext.register_models(roots, :car)
      end

      it "sets the AutoIncludeContext for roots" do
        expect(roots.map(&:auto_include_context).uniq.size).to eq 1
        expect(roots.first.auto_include_context.models).to match_array(roots)
      end

      it "sets the AutoIncludeContext for child nested associations" do
        expect(cars.map(&:auto_include_context).uniq.size).to eq 1
        expect(cars.first.auto_include_context.models).to match_array(cars)
      end
    end

    def create_mock_models(num)
      num.times.map { create_mock_model }
    end

    def create_mock_model(associations = {})
      model = AutoIncludeContextMockModel.new
      associations.each do |association, models|
        allow(model).to receive(:association).with(association) do
          OpenStruct.new(target: models)
        end
      end
      model
    end

    AutoIncludeContextMockModel = Struct.new(:auto_include_context)
  end
end
