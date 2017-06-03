// DIR-recursif.cpp�: d�finit le point d'entr�e pour l'application console.
//

#include "stdafx.h"
#include <Windows.h>

#define SEARCH_ALL L"\\*"

void ListDirectory(LPCWSTR directory);
void PrintLastError();
BOOL BuildSearchCommand(WCHAR* buffer, DWORD nBufferLength,WCHAR* directoryFullPath);

/* Point d'entr�e du programme */

int _tmain(int argc, TCHAR* argv[])
{
	/* V�rification du nombre d'arguments */
	if (argc == 2)
		ListDirectory(argv[1]);
	/* Sinon on affiche l'aide */
	else
		wprintf(L"Usage : %s <directory>\n",argv[0]);
	return 0;
}

BOOL BuildSearchCommand(WCHAR* buffer, DWORD nBufferLength,WCHAR* directoryFullPath)
{
	BOOL success = FALSE;

	ZeroMemory(buffer, nBufferLength * sizeof(WCHAR));

	wcsncpy(buffer, directoryFullPath,nBufferLength - 1);
	// wprintf(L"len(\"%ws\")=%d\n",SEARCH_ALL,sizeof(SEARCH_ALL));
	if (wcslen(buffer) - sizeof(SEARCH_ALL) < nBufferLength)
	{
		wcscat(buffer, SEARCH_ALL);
		success = TRUE;
	}

	return success;
}

/* Liste r�cursivement le r�pertoire pass� en param�tre */
void ListDirectory(LPCWSTR directory)
{	
	/* Buffer pour la concat�nation du r�pertoire + \* */
	WCHAR search[MAX_PATH];
	/* Chemin absolu du r�pertoire */
	WCHAR directoryFullPath[MAX_PATH];
	/* Information sur le fichier courrant (FindFirstFile,FindNextFile) */
	WIN32_FIND_DATAW currentFileData;
	/* Date au format jour mois ann�e du fichier courrant */
	SYSTEMTIME currentSystemTime;

	/* R�cup�re le chemin absolu du r�p�rtoire */
	GetFullPathNameW(directory, MAX_PATH, directoryFullPath,NULL);
	/* Change le r�pertoire de travail */
	SetCurrentDirectoryW(directory);
	
	/* Effectue la concat�nation du r�pertoire + \* */
	if (!BuildSearchCommand(search, MAX_PATH, directoryFullPath))
	{
		wprintf(L"Nom de r\202pertoire trop long\n");
		return;
	}

	wprintf(L"\nR\202pertoire de %ws\n\n", directoryFullPath);

	/* Trouve le premier fichier du r�pertoire � lister */
	HANDLE hListDirectory = FindFirstFileW(search, &currentFileData);
	if (hListDirectory != INVALID_HANDLE_VALUE)
	{
		do
		{
			/* Converti la structure de type FILETIME en structure de type SYSTEMTIME */
			if (FileTimeToSystemTime(&currentFileData.ftCreationTime, &currentSystemTime))
			{
				/* Si le fichier est un r�pertoire */
				if (currentFileData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
				{
					/* On affiche les informations et <REP> */
					wprintf(L"%02.2d/%02.2d/%04.4d  %02.2d:%02.2d   <REP>  %ws\n", currentSystemTime.wDay, currentSystemTime.wMonth, currentSystemTime.wYear, currentSystemTime.wHour, currentSystemTime.wMinute, currentFileData.cFileName);
					/* Avant de lister le r�pertoire fils on verifie que celui-ci n'est pas le r�pertoire courrant ou le r�pertoire parent */
					if (wcsncmp(currentFileData.cFileName,L".", MAX_PATH) != 0 && wcsncmp(currentFileData.cFileName,L"..", MAX_PATH) != 0)
					{
						/* On liste le r�pertoire fils */
						ListDirectory(currentFileData.cFileName);
						/* On se replace dans le r�pertoire courrant */
						SetCurrentDirectoryW(directoryFullPath);
					}
				}
				else
				{
					/* Sinon on afficher les informations sur le fichier */
					printf("%02.2d/%02.2d/%04.4d  %02.2d:%02.2d          %ws\n", currentSystemTime.wDay, currentSystemTime.wMonth, currentSystemTime.wYear, currentSystemTime.wHour, currentSystemTime.wMinute, currentFileData.cFileName);
				}
			}
			/* On passe au fichier suivant */
		} while (FindNextFileW(hListDirectory, &currentFileData) != 0);
		/* On a fini de lister le r�pertoire, on ferme le handle */
		FindClose(hListDirectory);
	}
	else
	{
		/* Quelque chose c'est mal pass� on affiche le message d'erreur */
		wprintf(L"FindFirstFileW(\"%ws\",%p) - failed\n",search,&currentFileData);
		PrintLastError();
	}
}

void PrintLastError()
{
	DWORD dLastError = GetLastError();
	LPCTSTR strErrorMessage = NULL;

	FormatMessage(
		FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS | FORMAT_MESSAGE_ARGUMENT_ARRAY | FORMAT_MESSAGE_ALLOCATE_BUFFER,
		NULL,
		dLastError,
		0,
		(LPWSTR)&strErrorMessage,
		0,
		NULL);

	fwprintf(stderr,L"%ws\n", strErrorMessage);
}

