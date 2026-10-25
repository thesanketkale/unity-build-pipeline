#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace UnityBuildPipeline.Sample
{
    /// <summary>
    /// Sample in-project build script delegating to the repository's build pipeline.
    /// </summary>
    public static class BuildScript
    {
        public static void BuildStandaloneWindows64()
        {
            var scenes = new[] { "Assets/Scenes/SampleScene.unity" };
            var options = new BuildPlayerOptions
            {
                scenes = scenes,
                locationPathName = "Builds/StandaloneWindows64/MinimalSample.exe",
                target = BuildTarget.StandaloneWindows64,
                options = BuildOptions.None
            };

            var report = BuildPipeline.BuildPlayer(options);
            if (report.summary.result == UnityEditor.Build.Reporting.BuildResult.Succeeded)
            {
                Debug.Log("[SampleBuildScript] StandaloneWindows64 build succeeded.");
                EditorApplication.Exit(0);
            }
            else
            {
                Debug.LogError($"[SampleBuildScript] Build failed: {report.summary.result}");
                EditorApplication.Exit(1);
            }
        }
    }
}
#endif
