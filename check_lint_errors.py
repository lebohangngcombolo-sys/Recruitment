import os
import subprocess
import sys

def check_flutter_analyze():
    """Run flutter analyze and check for specific errors"""
    try:
        result = subprocess.run(
            ['flutter', 'analyze', '--no-fatal-infos'],
            cwd='/mnt/c/Users/User/Recruitment/khono_recruite',
            capture_output=True,
            text=True
        )
        
        output = result.stdout + result.stderr
        
        # Check for the specific errors we were fixing
        errors_to_check = [
            "getUsers' isn't defined",
            "approveJob' is already defined", 
            "rejectJob' is already defined",
            "bulkApproveJobs' is already defined",
            "bulkRejectJobs' is already defined",
            "createJob' isn't defined",
            "viewCandidates' isn't defined"
        ]
        
        found_errors = []
        for error in errors_to_check:
            if error in output:
                found_errors.append(error)
        
        if found_errors:
            print("❌ Still found these errors:")
            for error in found_errors:
                print(f"   - {error}")
            return False
        else:
            print("✅ All target errors have been resolved!")
            
            # Show any remaining errors for context
            lines = output.split('\n')
            remaining_errors = [line for line in lines if 'error -' in line and not any(x in line for x in errors_to_check)]
            if remaining_errors:
                print(f"\n⚠️  There are still {len(remaining_errors)} other errors:")
                for error in remaining_errors[:5]:  # Show first 5
                    print(f"   - {error}")
            else:
                print("✅ No errors found in analysis!")
            return True
            
    except Exception as e:
        print(f"Error running flutter analyze: {e}")
        return False

if __name__ == "__main__":
    print("=== CHECKING FLUTTER LINT ERRORS ===")
    success = check_flutter_analyze()
    print("=" * 40)
    if success:
        print("✅ All targeted lint errors have been fixed!")
    else:
        print("❌ Some errors still need to be addressed.")
