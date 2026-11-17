import 'package:flutter_test/flutter_test.dart';
import 'package:buildtrack/utils/project_helpers.dart';

void main() {
  group('project budget helpers', () {
    test('uses the lower configured budget or contract amount', () {
      expect(
        remainingProjectBudget({
          'budget': 5000000,
          'contract_amount': 800000,
        }, 125000),
        675000,
      );
    });

    test('uses a single configured limit and preserves zero', () {
      expect(projectExpenseLimit({'contract_amount': 125000}), 125000);
      expect(projectExpenseLimit({'budget': 0, 'contract_amount': 800000}), 0);
      expect(remainingProjectBudget({}, 100), isNull);
    });
  });

  group('active project status helper', () {
    test(
      'counts ongoing and upcoming statuses but not completed or on hold',
      () {
        expect(countsAsActiveProject('Ongoing'), isTrue);
        expect(countsAsActiveProject('Active'), isTrue);
        expect(countsAsActiveProject('Upcoming'), isTrue);
        expect(countsAsActiveProject('Standby'), isTrue);
        expect(countsAsActiveProject('Completed'), isFalse);
        expect(countsAsActiveProject('On Hold'), isFalse);
      },
    );
  });
}
