import os
import re
import sys
import subprocess

# Paths
py_list_path = '/Users/anandasarangaram/Work/cl_server/sdks/pysdk/pysdk_full_tests.txt'
dartsdk_dir = '/Users/anandasarangaram/Work/cl_server/sdks/dartsdk'
brain_dir = '/Users/anandasarangaram/.gemini/antigravity/brain/ba1f784b-bf8d-46a1-bb13-b8f9f4c49fbd'

# Read Python tests
try:
    with open(py_list_path, 'r') as f:
        py_lines = [line.strip() for line in f if '::' in line]
except Exception as e:
    print(f'Error reading py_list: {e}')
    sys.exit(1)

# Get current Dart tests (to mark status)
dart_tests_found = set()
try:
    result = subprocess.run(['grep', '-r', "test('", os.path.join(dartsdk_dir, 'test')], capture_output=True, text=True)
    for line in result.stdout.splitlines():
        m = re.search(r"test\('(.*?)'", line)
        if m:
            dart_tests_found.add(m.group(1))
except Exception as e:
    print(f'Error grepping: {e}')

# 1. Generate Mapping Table
mapping = '# 1:1 Test Mapping: Python SDK vs Dart SDK\n\n'
mapping += '| # | Python Test File | Python Test Name | Dart Test File | Status |\n'
mapping += '|---|---|---|---|---|\n'

# 2. Generate granular Task List
task = '# 1:1 Test Parity Checklist\n\n'
task += '- [ ] Port/Refactor 39 Test Files for 1:1 Parity\n'

current_file = None
for i, line in enumerate(py_lines, 1):
    parts = line.split('::')
    file_path = parts[0]
    test_name = ' > '.join(parts[1:])
    simple_name = parts[-1]
    
    # Map Python file to Dart file name
    base = os.path.basename(file_path).replace('.py', '_test.dart')
    if 'test_integration' in file_path:
        rel_dart = os.path.join('test/integration', base)
    else:
        rel_dart = os.path.join('test', base)
    
    status_emoji = '✅ Mapped' if simple_name in dart_tests_found else '❌ Missing'
    mapping += f'| {i} | `{file_path}` | `{test_name}` | `{rel_dart}` | {status_emoji} |\n'
    
    if file_path != current_file:
        task += f'\n- [ ] File: `{file_path}` -> `{rel_dart}`\n'
        current_file = file_path
    
    check_status = 'x' if simple_name in dart_tests_found else ' '
    task += f'    - [{check_status}] `{simple_name}`\n'

# Write mapping to Dart project
try:
    with open(os.path.join(dartsdk_dir, 'test/pysdk_mapping.md'), 'w') as f:
        f.write(mapping)
    print(f'Saved mapping to {os.path.join(dartsdk_dir, "test/pysdk_mapping.md")}')
except Exception as e:
    print(f'Error writing mapping: {e}')

# Write task.md to brain
try:
    with open(os.path.join(brain_dir, 'task.md'), 'w') as f:
        f.write(task)
    print(f'Saved task.md to {os.path.join(brain_dir, "task.md")}')
except Exception as e:
    print(f'Error writing task.md: {e}')
