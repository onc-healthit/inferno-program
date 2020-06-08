# frozen_string_literal: true

require_relative '../test_helper'

describe Inferno::Terminology do
  NARRATIVE_STATUS_VS = 'http://hl7.org/fhir/us/core/ValueSet/us-core-narrative-status'
  BIRTH_SEX_VS = 'http://hl7.org/fhir/us/core/ValueSet/birthsex'
  ADMIN_GENDER_CS = 'http://terminology.hl7.org/CodeSystem/v3-AdministrativeGender'
  NF_CS = 'http://terminology.hl7.org/CodeSystem/v3-NullFlavor'

  before do
    # Load a minimal set of validators
    # Note: these could already be loaded through sequence_base
    Inferno::Terminology.load_validators('test/fixtures/validators')
  end

  describe '.loaded_validators' do
    it 'has the correct number of validators' do
      assert_equal 2, Inferno::Terminology.loaded_validators[NARRATIVE_STATUS_VS][:count]
      assert_equal 3, Inferno::Terminology.loaded_validators[BIRTH_SEX_VS][:count]
    end
  end

  describe 'load_validators' do
    it 'creates validators on StructureDefinitions' do
      refute_nil FHIR::DSTU2::StructureDefinition.vs_validators[NARRATIVE_STATUS_VS],
                 "No validator function set on StructureDefinition for the #{NARRATIVE_STATUS_VS} valueset"

      refute_nil FHIR::DSTU2::StructureDefinition.vs_validators[BIRTH_SEX_VS],
                 "No validator function set on StructureDefinition for the #{BIRTH_SEX_VS} valueset"
    end
  end

  describe '.validate_code' do
    describe 'with a valid ValueSet url' do
      describe 'with a nil CodeSystem url' do
        it 'returns true for a valid code' do
          assert Inferno::Terminology.validate_code(
            valueset_url: BIRTH_SEX_VS,
            code: 'M',
            system: nil
          )
        end

        it 'returns false for an invalid code' do
          refute Inferno::Terminology.validate_code(
            valueset_url: BIRTH_SEX_VS,
            code: 'R',
            system: nil
          )
        end
      end

      describe 'with a valid CodeSystem url' do
        it 'returns true for a valid code' do
          assert Inferno::Terminology.validate_code(
            valueset_url: BIRTH_SEX_VS,
            code: 'M',
            system: ADMIN_GENDER_CS
          )
        end

        it 'returns false for an invalid code' do
          refute Inferno::Terminology.validate_code(
            valueset_url: BIRTH_SEX_VS,
            code: 'R',
            system: ADMIN_GENDER_CS
          )
        end
      end

      describe 'with the wrong Codesystem url' do
        it 'returns false for a valid code from the valueset' do
          refute Inferno::Terminology.validate_code(
            valueset_url: BIRTH_SEX_VS,
            code: 'M',
            system: NF_CS
          )
        end
      end

      describe 'with an invalid CodeSystem url' do
        it 'returns false for a valid code' do
          refute Inferno::Terminology.validate_code(
            valueset_url: BIRTH_SEX_VS,
            code: 'M',
            system: 'http://fake-cs'
          )
        end

        it 'returns false for an invalid code' do
          refute Inferno::Terminology.validate_code(
            valueset_url: BIRTH_SEX_VS,
            code: 'R',
            system: 'http://fake-cs'
          )
        end
      end
    end

    describe 'with no ValueSet url' do
      it 'returns true for a valid code with a provided codesystem' do
        assert Inferno::Terminology.validate_code(
          valueset_url: nil,
          code: 'M',
          system: ADMIN_GENDER_CS
        )
      end

      it 'returns false for an invalid code with a provided codesystem' do
        refute Inferno::Terminology.validate_code(
          valueset_url: nil,
          code: 'R',
          system: ADMIN_GENDER_CS
        )
      end
    end

    describe 'with an invalid ValueSet url' do
      it 'raises an error' do
        assert_raises Inferno::Terminology::UnknownValueSetException do
          Inferno::Terminology.validate_code(
            valueset_url: 'http://a-fake-valueset',
            code: 'M',
            system: 'http://terminology.hl7.org/CodeSystem/v3-AdministrativeGender'
          )
        end

        assert_raises Inferno::Terminology::UnknownValueSetException do
          Inferno::Terminology.validate_code(
            valueset_url: 'http://a-fake-valueset',
            code: 'M',
            system: nil
          )
        end
      end
    end
  end
end
