# frozen_string_literal: true

require_relative '../test_helper'

describe Inferno::Terminology do
  NARRATIVE_STATUS_VS = 'http://hl7.org/fhir/us/core/ValueSet/us-core-narrative-status'
  BIRTH_SEX_VS = 'http://hl7.org/fhir/us/core/ValueSet/birthsex'
  ADMIN_GENDER_CS = 'http://terminology.hl7.org/CodeSystem/v3-AdministrativeGender'
  NF_CS = 'http://terminology.hl7.org/CodeSystem/v3-NullFlavor'
  VS_WITH_SNOMED = 'http://example.com/ValueSet/vs-with-snomed'

  before do
    # Load a minimal set of validators
    # Note: these could already be loaded through sequence_base
    Inferno::Terminology.load_validators('test/fixtures/validators')

    Inferno::Terminology.known_valuesets[VS_WITH_SNOMED] = {
      url: VS_WITH_SNOMED,
      count: 1,
      type: 'bloom',
      code_systems: [NF_CS, Inferno::Terminology::SNOMED_URL]
    }
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

  describe '.could_be_snomed_code?' do
    describe 'when no valueset_url is present' do
      it 'returns true if the system is SNOMED' do
        assert Inferno::Terminology.could_be_snomed_code?(system: Inferno::Terminology::SNOMED_URL)
      end

      it 'returns false if the system is not SNOMED' do
        refute Inferno::Terminology.could_be_snomed_code?(system: NF_CS)
      end
    end

    describe 'when valueset_url is present' do
      describe 'when the system is present' do
        it 'returns false if the system is not SNOMED' do
          refute Inferno::Terminology.could_be_snomed_code?(valueset_url: VS_WITH_SNOMED, system: NF_CS)
          refute Inferno::Terminology.could_be_snomed_code?(valueset_url: NARRATIVE_STATUS_VS, system: NF_CS)
        end

        it 'returns true if the system is SNOMED' do
          assert Inferno::Terminology.could_be_snomed_code?(valueset_url: VS_WITH_SNOMED, system: Inferno::Terminology::SNOMED_URL)
          assert Inferno::Terminology.could_be_snomed_code?(valueset_url: NARRATIVE_STATUS_VS, system: Inferno::Terminology::SNOMED_URL)
        end
      end

      describe 'when the system is not present' do
        it 'returns true if the ValueSet contains SNOMED' do
          assert Inferno::Terminology.could_be_snomed_code?(valueset_url: VS_WITH_SNOMED)
        end

        it 'returns false if the ValueSet does not contain SNOMED' do
          refute Inferno::Terminology.could_be_snomed_code?(valueset_url: NF_CS)
        end
      end
    end
  end

  describe '.uncoordinated_code' do
    describe 'with a non-SNOMED code' do
      it 'returns the original code' do
        code = 'abc|123'
        assert_equal code, Inferno::Terminology.uncoordinated_code(code: code)
        assert_equal code, Inferno::Terminology.uncoordinated_code(code: code, valueset_url: NARRATIVE_STATUS_VS)
        assert_equal code, Inferno::Terminology.uncoordinated_code(code: code, system: NF_CS)
      end
    end

    describe 'with a SNOMED code' do
      it 'returns the original code if it is not postcoordinated' do
        code = 'abc123'
        assert_equal code, Inferno::Terminology.uncoordinated_code(code: code, valueset_url: VS_WITH_SNOMED)
        assert_equal code, Inferno::Terminology.uncoordinated_code(code: code, system: Inferno::Terminology::SNOMED_URL)
      end

      it 'returns the base concept code if it is postcoordinated' do
        coordinated_code = '80146002|appendectomy|:260870009|priority|=25876001|emergency|'
        base_code = '80146002'
        assert_equal base_code, Inferno::Terminology.uncoordinated_code(code: coordinated_code, valueset_url: VS_WITH_SNOMED)
        assert_equal base_code, Inferno::Terminology.uncoordinated_code(code: coordinated_code, system: Inferno::Terminology::SNOMED_URL)
      end
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
