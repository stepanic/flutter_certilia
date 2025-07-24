#!/bin/bash

# End-to-end test runner for Certilia OAuth flow
# This script runs integration tests on different platforms

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}🧪 Certilia OAuth Flow E2E Test Runner${NC}"
echo "======================================"

# Check if server is running
check_server() {
    echo -e "\n${YELLOW}Checking server status...${NC}"
    HEALTH=$(curl -s https://uniformly-credible-opossum.ngrok-free.app/api/health 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Server is running${NC}"
        return 0
    else
        echo -e "${RED}❌ Server is not running${NC}"
        echo "Please start the server with: cd ../certilia-server && ./dev-start.sh"
        return 1
    fi
}

# Run widget tests
run_widget_tests() {
    echo -e "\n${YELLOW}Running widget tests...${NC}"
    flutter test test/widget_test.dart
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Widget tests passed${NC}"
        return 0
    else
        echo -e "${RED}❌ Widget tests failed${NC}"
        return 1
    fi
}

# Run integration tests
run_integration_tests() {
    local platform=$1
    echo -e "\n${YELLOW}Running integration tests on $platform...${NC}"
    
    case $platform in
        "chrome")
            flutter drive \
                --driver=test_driver/integration_test.dart \
                --target=integration_test/oauth_flow_test.dart \
                -d chrome \
                --web-port=9999
            ;;
        "ios")
            flutter test integration_test/oauth_flow_test.dart \
                --device-id=iPhone
            ;;
        "android")
            flutter test integration_test/oauth_flow_test.dart \
                --device-id=emulator
            ;;
        *)
            echo -e "${RED}Unknown platform: $platform${NC}"
            return 1
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Integration tests passed on $platform${NC}"
        return 0
    else
        echo -e "${RED}❌ Integration tests failed on $platform${NC}"
        return 1
    fi
}

# Main execution
main() {
    # Check prerequisites
    if ! check_server; then
        exit 1
    fi
    
    # Get Flutter dependencies
    echo -e "\n${YELLOW}Getting Flutter dependencies...${NC}"
    flutter pub get
    
    # Run tests based on arguments
    if [ $# -eq 0 ]; then
        # No arguments - run all tests
        run_widget_tests
        
        echo -e "\n${YELLOW}Select platform for integration tests:${NC}"
        echo "1) Chrome (Web)"
        echo "2) iOS Simulator"
        echo "3) Android Emulator"
        echo "4) All platforms"
        echo "5) Skip integration tests"
        
        read -p "Enter choice (1-5): " choice
        
        case $choice in
            1) run_integration_tests "chrome" ;;
            2) run_integration_tests "ios" ;;
            3) run_integration_tests "android" ;;
            4) 
                run_integration_tests "chrome"
                run_integration_tests "ios"
                run_integration_tests "android"
                ;;
            5) echo -e "${YELLOW}Skipping integration tests${NC}" ;;
            *) echo -e "${RED}Invalid choice${NC}" ;;
        esac
    else
        # Run specific test
        case $1 in
            "widget") run_widget_tests ;;
            "chrome") run_integration_tests "chrome" ;;
            "ios") run_integration_tests "ios" ;;
            "android") run_integration_tests "android" ;;
            "all")
                run_widget_tests
                run_integration_tests "chrome"
                run_integration_tests "ios"
                run_integration_tests "android"
                ;;
            *)
                echo -e "${RED}Usage: $0 [widget|chrome|ios|android|all]${NC}"
                exit 1
                ;;
        esac
    fi
    
    echo -e "\n${GREEN}✅ Test run complete!${NC}"
}

# Run main function
main "$@"