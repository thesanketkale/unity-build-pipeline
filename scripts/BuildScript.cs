#if UNITY_EDITOR
using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEngine;

namespace UnityBuildPipeline
{
    /// <summary>
    /// Production-grade batchmode build script for Unity continuous integration.
    /// Supports StandaloneWindows64, Android (APK/AAB), WebGL, and StandaloneLinux64.
    /// </summary>
    public static class BuildScript
    {
        private const string DefaultBuildDirectory = "Builds";

        /// <summary>
        /// General entry point invoked via -executeMethod UnityBuildPipeline.BuildScript.PerformBuild
        /// Resolves target platform and settings from command line arguments.
        /// </summary>
        public static void PerformBuild()
        {
            var args = ParseCommandLineArgs();
            string targetStr = GetArg(args, "-buildTarget", "StandaloneWindows64");

            if (!Enum.TryParse(targetStr, true, out BuildTarget target))
            {
                Console.WriteLine($"[BuildScript] ERROR: Invalid or unsupported -buildTarget: '{targetStr}'");
                EditorApplication.Exit(1);
                return;
            }

            switch (target)
            {
                case BuildTarget.StandaloneWindows64:
                    PerformWindowsBuild();
                    break;
                case BuildTarget.Android:
                    PerformAndroidBuild();
                    break;
                case BuildTarget.WebGL:
                    PerformWebGLBuild();
                    break;
                case BuildTarget.StandaloneLinux64:
                    PerformLinuxBuild();
                    break;
                default:
                    ExecuteBuild(target, args);
                    break;
            }
        }

        public static void PerformWindowsBuild()
        {
            var args = ParseCommandLineArgs();
            ExecuteBuild(BuildTarget.StandaloneWindows64, args);
        }

        public static void PerformAndroidBuild()
        {
            var args = ParseCommandLineArgs();

            // Configure Android signing if provided via environment or CLI
            string keystoreName = GetArgOrEnv(args, "-androidKeystoreName", "ANDROID_KEYSTORE_NAME");
            string keystorePass = GetArgOrEnv(args, "-androidKeystorePass", "ANDROID_KEYSTORE_PASS");
            string keyaliasName = GetArgOrEnv(args, "-androidKeyaliasName", "ANDROID_KEYALIAS_NAME");
            string keyaliasPass = GetArgOrEnv(args, "-androidKeyaliasPass", "ANDROID_KEYALIAS_PASS");
            string buildFormat = GetArgOrEnv(args, "-androidBuildFormat", "ANDROID_BUILD_FORMAT", "AAB");

            if (!string.IsNullOrEmpty(keystoreName) && File.Exists(keystoreName))
            {
                Console.WriteLine($"[BuildScript] Configuring Android Keystore: '{keystoreName}' (Alias: '{keyaliasName}')");
                PlayerSettings.Android.useCustomKeystore = true;
                PlayerSettings.Android.keystoreName = keystoreName;
                PlayerSettings.Android.keystorePass = keystorePass;
                PlayerSettings.Android.keyaliasName = keyaliasName;
                PlayerSettings.Android.keyaliasPass = keyaliasPass;
            }
            else
            {
                Console.WriteLine("[BuildScript] No custom keystore specified; building unsigned or debug Android package.");
            }

            // Set AAB vs APK
            bool isAab = string.Equals(buildFormat, "AAB", StringComparison.OrdinalIgnoreCase);
            EditorUserBuildSettings.buildAppBundle = isAab;
            Console.WriteLine($"[BuildScript] Android Package Format: {(isAab ? "Android App Bundle (.aab)" : "APK (.apk)")}");

            ExecuteBuild(BuildTarget.Android, args);
        }

        public static void PerformWebGLBuild()
        {
            var args = ParseCommandLineArgs();
            ExecuteBuild(BuildTarget.WebGL, args);
        }

        public static void PerformLinuxBuild()
        {
            var args = ParseCommandLineArgs();
            ExecuteBuild(BuildTarget.StandaloneLinux64, args);
        }

        private static void ExecuteBuild(BuildTarget target, Dictionary<string, string> args)
        {
            string projectName = Application.productName;
            if (string.IsNullOrEmpty(projectName)) projectName = "UnityBuild";

            string defaultExtension = GetDefaultExtension(target);
            string defaultPath = Path.Combine(DefaultBuildDirectory, target.ToString(), projectName + defaultExtension);
            string outputPath = GetArg(args, "-customBuildPath", defaultPath);

            // Configure versioning
            string buildVersion = GetArgOrEnv(args, "-customBuildVersion", "BUILD_VERSION");
            if (!string.IsNullOrEmpty(buildVersion))
            {
                Console.WriteLine($"[BuildScript] Setting PlayerSettings.bundleVersion to '{buildVersion}'");
                PlayerSettings.bundleVersion = buildVersion;
            }

            string buildNumber = GetArgOrEnv(args, "-customBuildNumber", "BUILD_NUMBER");
            if (!string.IsNullOrEmpty(buildNumber) && int.TryParse(buildNumber, out int bundleCode))
            {
                Console.WriteLine($"[BuildScript] Setting PlayerSettings.Android.bundleVersionCode to '{bundleCode}'");
                PlayerSettings.Android.bundleVersionCode = bundleCode;
            }

            // Ensure destination folder exists
            string directory = Path.GetDirectoryName(outputPath);
            if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
            {
                Directory.CreateDirectory(directory);
            }

            string[] scenes = GetEnabledScenes();
            if (scenes.Length == 0)
            {
                Console.WriteLine("[BuildScript] ERROR: No enabled scenes found in EditorBuildSettings!");
                EditorApplication.Exit(1);
                return;
            }

            Console.WriteLine($"[BuildScript] Starting build for target '{target}' -> '{outputPath}'");
            Console.WriteLine($"[BuildScript] Included scenes ({scenes.Length}):");
            foreach (var scene in scenes)
            {
                Console.WriteLine($"  - {scene}");
            }

            var buildPlayerOptions = new BuildPlayerOptions
            {
                scenes = scenes,
                locationPathName = outputPath,
                target = target,
                targetGroup = BuildPipeline.GetBuildTargetGroup(target),
                options = BuildOptions.None
            };

            bool devBuild = string.Equals(GetArg(args, "-developmentBuild", "false"), "true", StringComparison.OrdinalIgnoreCase);
            if (devBuild)
            {
                buildPlayerOptions.options |= BuildOptions.Development;
            }

            var report = BuildPipeline.BuildPlayer(buildPlayerOptions);
            BuildSummary summary = report.summary;

            Console.WriteLine("=== Build Summary ===");
            Console.WriteLine($"Result:        {summary.result}");
            Console.WriteLine($"Total Time:    {summary.totalTime.TotalSeconds:F2} seconds");
            Console.WriteLine($"Total Size:    {summary.totalSize / 1024 / 1024:F2} MB");
            Console.WriteLine($"Errors:        {summary.totalErrors}");
            Console.WriteLine($"Warnings:      {summary.totalWarnings}");
            Console.WriteLine($"Output:        {summary.outputPath}");

            if (summary.result == BuildResult.Succeeded)
            {
                Console.WriteLine("[BuildScript] SUCCESS: Build completed successfully.");
                EditorApplication.Exit(0);
            }
            else
            {
                Console.WriteLine($"[BuildScript] FAILED: Build finished with result '{summary.result}'.");
                EditorApplication.Exit(1);
            }
        }

        private static string[] GetEnabledScenes()
        {
            var scenes = new List<string>();
            foreach (var scene in EditorBuildSettings.scenes)
            {
                if (scene.enabled && !string.IsNullOrEmpty(scene.path))
                {
                    scenes.Add(scene.path);
                }
            }
            return scenes.ToArray();
        }

        private static string GetDefaultExtension(BuildTarget target)
        {
            switch (target)
            {
                case BuildTarget.StandaloneWindows64:
                case BuildTarget.StandaloneWindows:
                    return ".exe";
                case BuildTarget.Android:
                    return EditorUserBuildSettings.buildAppBundle ? ".aab" : ".apk";
                case BuildTarget.StandaloneLinux64:
                    return ".x86_64";
                case BuildTarget.StandaloneOSX:
                    return ".app";
                case BuildTarget.WebGL:
                    return ""; // WebGL outputs a directory
                default:
                    return "";
            }
        }

        private static Dictionary<string, string> ParseCommandLineArgs()
        {
            var args = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            string[] rawArgs = Environment.GetCommandLineArgs();

            for (int i = 0; i < rawArgs.Length; i++)
            {
                if (rawArgs[i].StartsWith("-") && i + 1 < rawArgs.Length && !rawArgs[i + 1].StartsWith("-"))
                {
                    args[rawArgs[i]] = rawArgs[i + 1];
                    i++;
                }
            }
            return args;
        }

        private static string GetArg(Dictionary<string, string> args, string key, string defaultValue = "")
        {
            return args.TryGetValue(key, out string value) ? value : defaultValue;
        }

        private static string GetArgOrEnv(Dictionary<string, string> args, string cliKey, string envKey, string defaultValue = "")
        {
            if (args.TryGetValue(cliKey, out string value) && !string.IsNullOrEmpty(value))
            {
                return value;
            }
            string envValue = Environment.GetEnvironmentVariable(envKey);
            if (!string.IsNullOrEmpty(envValue))
            {
                return envValue;
            }
            return defaultValue;
        }
    }
}
#endif
