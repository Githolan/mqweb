/**
 * Test script for MQL4-WEB API
 * Run: node Scripts/test-api.js
 */

const http = require('http');

const HOST = '127.0.0.1';
const PORT = 3030;

function makeRequest(path, method = 'GET', body = null) {
    return new Promise((resolve, reject) => {
        const options = {
            hostname: HOST,
            port: PORT,
            path: path,
            method: method,
            headers: {
                'Content-Type': 'application/json'
            }
        };

        console.log(`\n📡 ${method} http://${HOST}:${PORT}${path}`);

        const req = http.request(options, (res) => {
            let data = '';

            res.on('data', chunk => {
                data += chunk;
            });

            res.on('end', () => {
                console.log(`   Status: ${res.statusCode}`);
                console.log(`   Response: ${data.substring(0, 200)}`);
                resolve({ status: res.statusCode, data });
            });
        });

        req.on('error', (err) => {
            console.log(`   ❌ Error: ${err.message}`);
            reject(err);
        });

        req.setTimeout(5000, () => {
            req.destroy();
            reject(new Error('Timeout'));
        });

        if (body) {
            req.write(JSON.stringify(body));
        }

        req.end();
    });
}

async function runTests() {
    console.log('========================================');
    console.log('  MQL4-WEB API Test Script');
    console.log('========================================');
    console.log(`Server: ${HOST}:${PORT}`);
    console.log('');

    const tests = [
        {
            name: 'Health Check',
            path: '/health',
            method: 'GET'
        },
        {
            name: 'Get Commands (empty)',
            path: '/get-commands',
            method: 'GET'
        },
        {
            name: 'Send Market Data',
            path: '/receive-data?type=market&symbol=EURUSD&bid=1.0850&ask=1.0851&spread=10&digits=4&balance=10000&equity=10050&profit=50&margin=500&time=' + Date.now(),
            method: 'GET'
        },
        {
            name: 'Get Data',
            path: '/data',
            method: 'GET'
        },
        {
            name: 'Send Command (POST)',
            path: '/command',
            method: 'POST',
            body: { type: 'alert', message: 'Test from script' }
        }
    ];

    let passed = 0;
    let failed = 0;

    for (const test of tests) {
        try {
            console.log(`\n🧪 Test: ${test.name}`);
            const result = await makeRequest(test.path, test.method, test.body);

            if (result.status === 200) {
                console.log('   ✅ PASSED');
                passed++;
            } else {
                console.log('   ❌ FAILED (non-200 status)');
                failed++;
            }
        } catch (err) {
            console.log(`   ❌ FAILED: ${err.message}`);
            failed++;
        }
    }

    console.log('\n========================================');
    console.log(`  Results: ${passed} passed, ${failed} failed`);
    console.log('========================================\n');

    if (failed > 0) {
        process.exit(1);
    }
}

runTests().catch(err => {
    console.error('Fatal error:', err);
    process.exit(1);
});
