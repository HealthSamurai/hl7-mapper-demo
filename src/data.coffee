module.exports.mapping = """
$structure:
  - ['', 'PID', ['*?', 'PD1'], ['*?', 'NK1']]
  - ['?', 'PV1']

resourceType: Bundle
type: transaction
entry:
  $filter: flatten
  $value:
    - transaction:
        method: POST
        url: /Patient
      resource:
        id: REFERENCE_PATIENT_ID
        resourceType: Patient
        multipleBirthInteger: $ PID.24
        deceasedBoolean: $ PID.30
        birthDate: $ PID.7 | dateTime
        gender: $ PID.8 | translateCode("gender")

        name:
          $foreach: PID.5 as name
          $value:
            period:
              start: $ name.12 | dateTime
              end: $ name.13 | dateTime

            given:
              $foreach: name.2 as given
              $value: $ given | capitalize
            middle:
              $foreach: name.3 as middle
              $value: $ middle | capitalize
            family:
              $foreach: name.1 as family
              $value: $ family | capitalize
            suffix:
              $foreach: name.4 as suffix
              $value: $ suffix
            prefix:
              $foreach: name.5 as prefix
              $value: $ prefix
            text: '{{name.5}} {{name.2}} {{name.3}} {{name.1}} {{name.4}} {{name.6}}'

        address:
          $foreach: PID.11 as addr
          $value:
            line:
              - $ addr.1
              - $ addr.2
              - $ addr.3

            city: $ addr.3
            state: $ addr.4
            postalCode: $ addr.5
            country: $ addr.6
            period:
              start: $ addr.12 | dateTime
              end: $ addr.13 | dateTime
            text: "{{addr.1}} {{addr.2}} {{addr.3}} {{addr.4}} {{addr.5}} {{addr.6}}"

        identifier:
          $filter: flatten
          $value:
            - $foreach: PID.2, PID.3, PID.4, PID.18 as id
              $value:
                $if: id.1
                value: $ id.1
                system: $ id.4

                period:
                  start: $ id.7 | dateTime
                  end: $ id.8 | dateTime

                type:
                  text:
                    $case: id.path
                    'PID.2': External ID
                    'PID.3': Internal ID
                    'PID.4': Alternate ID
                    'PID.18': Account number

            - $if: PID.19
              value: $ PID.19
              system: http://hl7.org/fhir/sid/us-ssn
              type:
                text: Social Security Number

            - $if: PID.20.1 && PID.20.2
              value: '{{PID.20.1}} {{PID.20.2}}'
              system: urn:oid:2.16.840.1.113883.4.3.36
              type:
                text: Driver License

        telecom:
          $foreach: PID.13, PID.14 as tel
          $value:
            $if: tel.1
            $value:
              use:
                $case: tel.path
                'PID.13': home
                'PID.14': work

              value: $ tel.1
              system: $ tel.3

        contact:
          $foreach: PID.NK1 as nk1
          $value:
            period:
              start: $ nk1.8
              end: $ nk1.9

            gender: $ nk1.15 | translateCode("gender")
            relationship:
              coding:
                - code: $ nk1.3.1

            name:
              period:
                start: $ nk1.2~.12 | dateTime
                end: $ nk1.2~.13 | dateTime
              use: $ nk1.2~.7 || "official"
              given:
                - $ nk1.2~.2
              family:
                - $ nk1.2~.1
              middle:
                - $ nk1.2~.3
              suffix:
                - $ nk1.2~.4
              prefix:
                - $ nk1.2~.5
              text: '{{nk1.2~.5}} {{nk1.2~.2}} {{nk1.2~.3}} {{nk1.2~.1}} {{nk1.2~.4}} {{nk1.2~.6}}'

            address:
              line:
                - $ nk1.4~.1
                - $ nk1.4~.2
                - $ nk1.4~.3

              city: $ nk1.4~.3
              state: $ nk1.4~.4
              postalCode: $ nk1.4~.5
              country: $ nk1.4~.6
              period:
                start: $ nk1.4~.12 | dateTime
                end: $ nk1.4~.13 | dateTime

              text: "{{nk1.4~.1}} {{nk1.4~.2}} {{nk1.4~.3}} {{nk1.4~.4}} {{nk1.4~.5}} {{nk1.4~.6}}"

              type: $ nk1.4~.7
              use: 'Mailing Address'

    - transaction:
        method: POST
        url: /Encounter
      resource:
        resourceType: Encounter
        class: $ PV1.2
        identifier:
          - value: $ PV1.19.1

        participant:
          $foreach: PV1.7, PV1.8, PV1.9, PV1.17 as physician
          $value:
            $if: physician.1
            type:
              codings:
                - code:
                    $case: physician.path
                    'PV1.7': ATND
                    'PV1.8': REF
                    'PV1.9': CON
                    'PV1.17': ADM
                  system: http://hl7.org/fhir/v3/ParticipationType

            period:
            individual:
              reference: "PRACTITIONER_{{physician.1}}"

        patient:
          reference: REFERENCE_PATIENT_ID

        location:
          location:
            reference: "LOCATION_{{ PV1.3 | md5 }}"
          status: active

    - $filter: uniq("resource.id")
      $value:
        $foreach: PV1.7, PV1.8, PV1.9, PV1.17 as physician
        $value:
          $if: physician.1
          $value:
            transaction:
              method: POST
              url: /Practitioner
            resource:
              id: "PRACTITIONER_{{physician.1}}"
              resourceType: Practitioner
              identifier:
                - value: $ physician.1

              name:
                given:
                  $foreach: physician.3 as given
                  $value: $ given | capitalize
                middle:
                  $foreach: physician.4 as middle
                  $value: $ middle | capitalize
                family:
                  $foreach: physician.2 as family
                  $value: $ family | capitalize

    - $if: PV1.3
      transaction:
          method: POST
          url: /Location

      resource:
        $let:
          locationStr:
            $filter:
              - compact
              - join(".")

            $value:
              - $ PV1.3.7 | trim
              - $ PV1.3.8 | trim
              - $ PV1.3.2 | trim
              - $ PV1.3.3 | trim

        id: "LOCATION_{{ PV1.3 | md5 }}"
        resourceType: Location
        status: active
        identifier:
          - value: $ locationStr

        name: $ locationStr
"""

module.exports.message = """
MSH|^~\&|MS4ADT|001|UST|001|20130716075007||ADT^A08|00000000012988788|P|2.3
EVN|A08|20130716075004||ITOI|HIMACARRAM
PID|1|010107127^^^MS4^PN^|160922^^^MS4^MR^001|160922^^^MS4^MR^001|WANDA^LUXENBURG^IVANOVNA^^||19330910|F||C|STRAWBERRY AVE^FOUR OAKS LODGE^ALBUKERKA^CA^98765^USA^^||(111)222-3333||ENG|W|CHR|11115555555^^^MS4001^AN^001|333-22-1111||||OKLAHOMA||||||20120812|Y
PD1||||07302^DJANG^EIMING^^^|||U
NK1|1|MOCK^LAWRENCE^E^^|Z|4357 COBBLESTONE LANE^^LA CANDADA^CA^91011^^|(818)790-4099||S|||SALESMAN|||KONICA BUSINESS MACHINE|M|M|19610429|||||||||PRE||||||||010061010^^^MS4^PN^||C||572-33-5959
NK1|2|MOCK^RUSSEL^^^|Z|3420 LE BETHON ST^^SUNLAND^CA^91040^^|(818)249-3925||R||||||UNKNOWN||M||||||||||UNK||||||||000323302^^^MS4^PN^||T||          1
PV1||I|TELE^ 581^ A^001^OCCPD|1|||01552^ANDERSON^CHARLES^A^^^MD^^^^^^^|||MED||||1|||01552^ANDERSON^CHARLES^A^^^MD^^^^^^^|I|666|0401|5||||||||N|||||||E|||001|OCCPD||||201307021300|201307091552|69206.42|69206.42
DG1|1|I9|518.81|ACUTE RESPIRATOR FAILURE||A|||||||||0|||||||||||Y
DG1|2|I9|518.84|ACUTE & CHR RESP FAILURE||D|||||||||1|||||||||||Y
DG1|3|I9|599.0|URIN TRACT INFECTION NOS||D|||||||||2|||||||||||Y
DG1|4|I9|427.31|ATRIAL FIBRILLATION||D|||||||||2|||||||||||Y
DG1|5|I9|401.9|HYPERTENSION NOS||D|||||||||2|||||||||||Y
DG1|6|I9|496|CHR AIRWAY OBSTRUCT NEC||D|||||||||2|||||||||||Y
DG1|7|I9|244.9|HYPOTHYROIDISM NOS||D|||||||||2|||||||||||Y
DRG|00208
PR1|1|I9|9671|CONT INVAS MV-<96 HRS|20130702||||||31853^CRABB^JONATHAN^W^^MD
PR1|2|I9|9604|INSERT ENDOTRACHEAL TUBE|20130702||||||31853^CRABB^JONATHAN^W^^MD
PR1|3|I9|9394|NEBULIZER THERAPY|20130703||||||01552^ANDERSON^CHARLES^A^^MD
PR1|4|I9|9390|NON-INVASIVE MECH VENT|20130706||||||01552^ANDERSON^CHARLES^A^^MD
GT1|1|010107127^^^MS4^PN^|MOCK^WANDA^J^^|MOCK^LAWRENCE^E^^|2820 SYCAMORE AVE^TWELVE OAKS LODGE^MONTROSE^CA^91214^USA^|(818)249-3361||19301013|F||A|354-22-1840||||RETIRED|^^^^00000^|||||||20130711|||||0000007496|W||||||||Y|||CHR||||||||RETIRED||||||C
IN1|1||0401|MEDICARE IP|^^^^     |||||||19951001|||MCR|MOCK^WANDA^J^^|A|19301013|2820 SYCAMORE AVE^TWELVE OAKS LODGE^MONTROSE^CA^91214^USA^^^|||1||||||||||||||354221840A|||||||F|^^^^00000^|N||||010107127
IN2||354221840|0000007496^RETIRED|||354221840A||||||||||||||||||||||||||||||Y|||CHR||||W|||RETIRED|||||||||||||||||(818)249-3361||||||||C
IN1|2||2320|AETNA PPO|PO BOX 14079^PO BOX 14079^LEXINGTON^KY^40512|||081140101400020|RETIRED|||20130101|||COM|MOCK^WANDA^J^^|A|19301013|2820 SYCAMORE AVE^TWELVE OAKS LODGE^MONTROSE^CA^91214^USA^^^|||2||||||||||||||811001556|||||||F|^^^^00000^|N||||010107127
IN2||354221840|0000007496^RETIRED|||||||||||||||||||||||||||||||||Y|||CHR||||W|||RETIRED|||||||||||||||||(818)249-3361||||||||C
"""
