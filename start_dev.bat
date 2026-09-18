@echo off
echo =======================================================
echo Starting Vepo Development Environment
echo =======================================================

echo.
echo [1/3] Starting Hardhat Local Node...
start "Vepo Hardhat Node" cmd /k "cd contracts && npx hardhat node"

echo.
echo Waiting 5 seconds for the node to spin up...
timeout /t 5 /nobreak >nul

echo.
echo [2/3] Deploying Smart Contracts...
cd contracts
call npx hardhat run scripts/deploy.ts --network localhost
cd ..

echo.
echo [3/3] Starting Vue Frontend...
start "Vepo Frontend" cmd /k "cd frontend && npm run dev"

echo.
echo =======================================================
echo Done! 
echo The frontend will be available at http://localhost:5173
echo You can close those new terminal windows to stop the servers.
echo =======================================================
