/**
 * Script to call the deployed backfillMessageEmbeddings Cloud Function
 *
 * Usage: node scripts/callBackfill.js
 */

const https = require('https');
const { exec } = require('child_process');
const util = require('util');
const execPromise = util.promisify(exec);

async function callBackfillFunction() {
  console.log('🚀 Calling backfillMessageEmbeddings Cloud Function...');

  try {
    // Get Firebase ID token using gcloud (requires gcloud auth login)
    console.log('🔑 Getting authentication token...');

    const { stdout: token } = await execPromise(
      'gcloud auth print-identity-token --audiences=https://us-central1-messageai-dev-1f2ec.cloudfunctions.net/backfillMessageEmbeddings'
    );

    const authToken = token.trim();
    console.log('✅ Got authentication token');

    // Call the Cloud Function
    const data = JSON.stringify({
      data: {
        batchSize: 50,
        skipExisting: true
      }
    });

    const options = {
      hostname: 'us-central1-messageai-dev-1f2ec.cloudfunctions.net',
      path: '/backfillMessageEmbeddings',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${authToken}`,
        'Content-Length': data.length
      }
    };

    console.log('📞 Calling Cloud Function...');

    const req = https.request(options, (res) => {
      let responseData = '';

      res.on('data', (chunk) => {
        responseData += chunk;
      });

      res.on('end', () => {
        console.log('\n📊 Response:');
        try {
          const result = JSON.parse(responseData);
          console.log(JSON.stringify(result, null, 2));

          if (result.result) {
            console.log('\n✅ Backfill Summary:');
            console.log(`   ✅ Processed: ${result.result.processed || 0}`);
            console.log(`   ⏭️  Skipped: ${result.result.skipped || 0}`);
            console.log(`   ❌ Errors: ${result.result.errors || 0}`);

            if (result.result.hasMore) {
              console.log('\n⚠️  More messages exist. Run again to process next batch.');
            } else {
              console.log('\n🎉 All messages in this batch processed!');
            }
          }
        } catch (e) {
          console.log(responseData);
        }
      });
    });

    req.on('error', (error) => {
      console.error('❌ Error calling function:', error);
    });

    req.write(data);
    req.end();

  } catch (error) {
    if (error.message.includes('gcloud')) {
      console.error('\n❌ Error: gcloud CLI not authenticated');
      console.error('\n📝 Please run: gcloud auth login');
      console.error('   Then try again.');
    } else {
      console.error('❌ Error:', error.message);
    }
    process.exit(1);
  }
}

// Run
callBackfillFunction();
